# %% [markdown]
# # Boston Dynamics — ML Model Training (Fleet + Customer 360)
#
# Trains, evaluates and registers the models used by the Boston Dynamics
# Intelligence Agent, then batch-scores customers into
# `BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_SCORES`.
#
# **Fleet models**
# 1. Predictive Maintenance — Random Forest classifier (component needs attention)
# 2. Anomaly Detection — statistical Z-score over daily telemetry
# 3. Remaining Useful Life — Gradient Boosting regressor (days to replacement)
#
# **Customer 360 models**
# 4. Churn Risk — XGBoost classifier (probability of churn / non-renewal)
# 5. Health Score — XGBoost regressor (0-100 composite account health)
# 6. Expansion Propensity — XGBoost classifier (probability of expansion win)
#
# All trained models are logged to the Snowflake Model Registry in
# `BD_INTELLIGENCE.ML`. Customer scores are produced by the registered model
# versions (`ModelVersion.run`), not by local objects.
#
# **Prerequisites:** run SQL steps 01-06 first.

# %%
import warnings
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from sklearn.metrics import classification_report, mean_absolute_error, r2_score, roc_auc_score
from sklearn.model_selection import GroupKFold, KFold, StratifiedGroupKFold, train_test_split
from sklearn.preprocessing import LabelEncoder
from snowflake.ml.registry import Registry
from snowflake.snowpark import Session

warnings.filterwarnings('ignore')

try:
    from snowflake.snowpark.context import get_active_session
    session = get_active_session()
except Exception:
    # Running outside Snowflake Notebooks: use a local connection profile
    session = Session.builder.config('connection_name', 'AWS161').create()

session.use_database('BD_INTELLIGENCE')
session.use_warehouse('BOSTON_DYNAMICS_WH')
session.sql('CREATE SCHEMA IF NOT EXISTS BD_INTELLIGENCE.ML').collect()
registry = Registry(session=session, database_name='BD_INTELLIGENCE', schema_name='ML')
MODEL_VERSION = 'V1'
RANDOM_STATE = 42
print('Session ready:', session.get_current_account(), session.get_current_role())


def register(model, name, sample_input, comment, metrics):
    """Log a model version to the registry, replacing any previous copy so reruns are idempotent."""
    existing = registry.show_models()
    if not existing.empty and name.upper() in existing['name'].str.upper().values:
        registry.delete_model(name)
    mv = registry.log_model(
        model,
        model_name=name,
        version_name=MODEL_VERSION,
        sample_input_data=sample_input,
        comment=comment,
        target_platforms=['WAREHOUSE'],
    )
    for k, v in metrics.items():
        mv.set_metric(k, float(v))
    print(f'Registered {name} {MODEL_VERSION}: {metrics}')
    return mv


# %% [markdown]
# ## 1. Fleet: load training data

# %%
df_telemetry = session.table('BD_INTELLIGENCE.ANALYTICS.TELEMETRY_DAILY_SUMMARY').to_pandas()
df_components = session.table('BD_INTELLIGENCE.ANALYTICS.COMPONENT_HEALTH').to_pandas()
df_components['LIFECYCLE_RATIO'] = df_components['DAYS_SINCE_INSTALL'] / df_components['EXPECTED_LIFESPAN_DAYS']
print(f'Telemetry rows (robot-days): {len(df_telemetry):,}')
print(f'Components: {len(df_components):,}')

# %% [markdown]
# ## 2. Fleet: Predictive Maintenance (Random Forest)

# %%
df_components['NEEDS_ATTENTION'] = df_components['COMPONENT_STATUS'].isin(['Degraded', 'Needs Replacement', 'Failed']).astype(int)
df_components['MODEL_ENC'] = LabelEncoder().fit_transform(df_components['ROBOT_MODEL'])
df_components['TYPE_ENC'] = LabelEncoder().fit_transform(df_components['COMPONENT_TYPE'])

maint_features = ['DAYS_SINCE_INSTALL', 'EXPECTED_LIFESPAN_DAYS', 'CURRENT_RUNTIME_HOURS',
                  'LIFECYCLE_RATIO', 'MODEL_ENC', 'TYPE_ENC']
X = df_components[maint_features].fillna(0).astype(float)
y = df_components['NEEDS_ATTENTION']
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y)

maint_model = RandomForestClassifier(n_estimators=200, max_depth=8, class_weight='balanced', random_state=RANDOM_STATE)
maint_model.fit(X_train, y_train)
maint_auc = roc_auc_score(y_test, maint_model.predict_proba(X_test)[:, 1])
print('=== Predictive Maintenance ===')
print(classification_report(y_test, maint_model.predict(X_test)))
print(f'ROC AUC: {maint_auc:.3f}')

# %% [markdown]
# ## 3. Fleet: Anomaly Detection (Z-score)

# %%
anomaly_features = ['AVG_MOTOR_TEMP_C', 'MAX_MOTOR_TEMP_C', 'AVG_VIBRATION', 'MAX_VIBRATION', 'AVG_JOINT_LOAD', 'ERROR_COUNT']
z = (df_telemetry[anomaly_features] - df_telemetry[anomaly_features].mean()) / df_telemetry[anomaly_features].std()
df_telemetry['MAX_ZSCORE'] = z.abs().max(axis=1)
df_telemetry['IS_ANOMALY'] = (df_telemetry['MAX_ZSCORE'] > 2.0).astype(int)
anomaly_rate = df_telemetry['IS_ANOMALY'].mean()
print(f'=== Anomaly Detection === robot-days: {len(df_telemetry):,}  anomalies: {df_telemetry.IS_ANOMALY.sum():,} ({anomaly_rate:.1%})')

# %% [markdown]
# ## 4. Fleet: Remaining Useful Life (Gradient Boosting)
#
# Target: field-engineer remaining-life estimate recorded at the last inspection
# (`INSPECTION_RUL_DAYS`). The model predicts it from observable age, lifespan,
# runtime and component attributes, so it can estimate RUL between inspections.

# %%
rul_features = ['DAYS_SINCE_INSTALL', 'EXPECTED_LIFESPAN_DAYS', 'CURRENT_RUNTIME_HOURS', 'LIFECYCLE_RATIO',
                'RUNTIME_PER_DAY', 'MODEL_ENC', 'TYPE_ENC']
df_components['RUNTIME_PER_DAY'] = df_components['CURRENT_RUNTIME_HOURS'] / df_components['DAYS_SINCE_INSTALL'].clip(lower=1)
X_rul = df_components[rul_features].fillna(0).astype(float)
y_rul = df_components['INSPECTION_RUL_DAYS'].astype(float)
Xr_train, Xr_test, yr_train, yr_test = train_test_split(X_rul, y_rul, test_size=0.2, random_state=RANDOM_STATE)

rul_model = GradientBoostingRegressor(n_estimators=300, max_depth=4, learning_rate=0.05, random_state=RANDOM_STATE)
rul_model.fit(Xr_train, yr_train)
pred = rul_model.predict(Xr_test)
rul_mae, rul_r2 = mean_absolute_error(yr_test, pred), r2_score(yr_test, pred)
print(f'=== RUL === target median {y_rul.median():.0f} days  MAE: {rul_mae:.1f} days  R2: {rul_r2:.3f}')

# %% [markdown]
# ## 5. Customer 360: load point-in-time features
#
# `ANALYTICS.CUSTOMER_ML_FEATURES` holds monthly snapshots per customer.
# `SNAPSHOT_K = 0` is today's scoring row; older snapshots carry forward-looking
# labels (churn / expansion in the next 180 days). Training on snapshots taken
# *before* the outcome teaches the models the early-warning pattern, which is
# what at-risk customers look like today. Cross-validation is grouped by
# customer so no customer appears in both train and test folds.

# %%
feat = session.table('BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_FEATURES').to_pandas()

FEATURES = [
    'TENURE_DAYS', 'TOTAL_ROBOTS', 'SITE_COUNT',
    'INCIDENTS_PER_ROBOT_90D', 'CRITICAL_INCIDENTS_90D',
    'TICKETS_PER_ROBOT_90D', 'HIGH_PRIORITY_TICKETS_90D', 'SLA_MET_PCT_90D',
    'AVG_TICKET_CSAT_90D', 'AVG_RESOLUTION_HOURS_90D',
    'AVG_NPS_6M', 'NPS_TREND', 'UTILIZATION_PCT_30D', 'USAGE_TREND_PCT', 'AUTONOMY_PCT_30D',
    'LATE_PAYMENT_PCT_12M', 'AVG_DAYS_LATE_12M', 'NEGATIVE_SENTIMENT_PCT_90D', 'INTERACTIONS_90D',
]
FEATURE_LABELS = {
    'INCIDENTS_PER_ROBOT_90D': 'High incident rate', 'CRITICAL_INCIDENTS_90D': 'Critical incidents',
    'TICKETS_PER_ROBOT_90D': 'High ticket volume', 'HIGH_PRIORITY_TICKETS_90D': 'High-priority tickets',
    'SLA_MET_PCT_90D': 'SLA misses', 'AVG_TICKET_CSAT_90D': 'Low ticket CSAT',
    'AVG_RESOLUTION_HOURS_90D': 'Slow ticket resolution', 'AVG_NPS_6M': 'Low NPS',
    'NPS_TREND': 'Declining NPS', 'UTILIZATION_PCT_30D': 'Low utilization',
    'USAGE_TREND_PCT': 'Declining usage', 'AUTONOMY_PCT_30D': 'Low autonomy',
    'LATE_PAYMENT_PCT_12M': 'Late payments', 'AVG_DAYS_LATE_12M': 'Days late on invoices',
    'NEGATIVE_SENTIMENT_PCT_90D': 'Negative sentiment', 'INTERACTIONS_90D': 'Engagement level',
    'TENURE_DAYS': 'Tenure', 'TOTAL_ROBOTS': 'Fleet size', 'SITE_COUNT': 'Site count',
}

feat[FEATURES] = feat[FEATURES].apply(pd.to_numeric, errors='coerce').astype(float)
feat[FEATURES] = feat[FEATURES].fillna(feat[FEATURES].median())
scoring = feat[feat['SNAPSHOT_K'] == 0].reset_index(drop=True)
X_c = scoring[FEATURES]
print(f'Snapshots: {len(feat):,}  scoring rows: {len(scoring)}  features: {len(FEATURES)}')
print(scoring['LIFECYCLE_STAGE'].value_counts().to_string())


def grouped_oof(model, X, y, groups, n_splits=5):
    """Out-of-fold probabilities with customer-grouped, stratified folds."""
    oof = np.zeros(len(y))
    for tr, te in StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=RANDOM_STATE).split(X, y, groups):
        model.fit(X.iloc[tr], y.iloc[tr])
        oof[te] = model.predict_proba(X.iloc[te])[:, 1]
    return oof

# %% [markdown]
# ## 6. Churn Risk (XGBoost classifier)
#
# Label: customer churned within 180 days of the snapshot.

# %%
train_churn = feat[feat['CHURN_NEXT_180D'].notna()].reset_index(drop=True)
y_churn = train_churn['CHURN_NEXT_180D'].astype(int)
churn_model = xgb.XGBClassifier(n_estimators=200, max_depth=3, learning_rate=0.05, subsample=0.8,
                                colsample_bytree=0.8, min_child_weight=3,
                                scale_pos_weight=(len(y_churn) - y_churn.sum()) / max(y_churn.sum(), 1),
                                random_state=RANDOM_STATE, eval_metric='logloss')
churn_oof = grouped_oof(churn_model, train_churn[FEATURES], y_churn, train_churn['CUSTOMER_ID'])
churn_auc = roc_auc_score(y_churn, churn_oof)
churn_model.fit(train_churn[FEATURES], y_churn)
print(f'=== Churn Risk === training snapshots: {len(y_churn)}  positives: {y_churn.sum()}  '
      f'grouped 5-fold CV ROC AUC: {churn_auc:.3f}')

# %% [markdown]
# ## 7. Health Score (XGBoost regressor)
#
# Target: a 0-100 composite of adoption, sentiment, support, reliability and
# payment health (see KB article "Customer Health Score Methodology"). The model
# learns this composite from the raw signals so it can score accounts with
# partially missing data consistently.

# %%
def clip01(s):
    return s.clip(lower=0, upper=1)

health_target = 100 * (
    0.25 * clip01(X_c['UTILIZATION_PCT_30D'] / 100)
    + 0.20 * clip01(X_c['AVG_NPS_6M'] / 10)
    + 0.15 * clip01(X_c['SLA_MET_PCT_90D'] / 100)
    + 0.15 * clip01(1 - X_c['LATE_PAYMENT_PCT_12M'] / 100)
    + 0.15 * clip01(1 - X_c['NEGATIVE_SENTIMENT_PCT_90D'] / 100)
    + 0.10 * clip01(1 - X_c['INCIDENTS_PER_ROBOT_90D'] / 3)
)
health_model = xgb.XGBRegressor(n_estimators=300, max_depth=3, learning_rate=0.05, subsample=0.8,
                                random_state=RANDOM_STATE)
health_oof = np.zeros(len(health_target))
for tr, te in KFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE).split(X_c):
    health_model.fit(X_c.iloc[tr], health_target.iloc[tr])
    health_oof[te] = health_model.predict(X_c.iloc[te])
health_mae, health_r2 = mean_absolute_error(health_target, health_oof), r2_score(health_target, health_oof)
health_model.fit(X_c, health_target)
print(f'=== Health Score === 5-fold CV MAE: {health_mae:.2f} points  R2: {health_r2:.3f}')

# %% [markdown]
# ## 8. Expansion Propensity (XGBoost classifier)
#
# Label: won an Expansion / Upsell / New Site / Services opportunity within 180
# days of the snapshot. Pipeline and bookings columns are not used as features.

# %%
train_exp = feat[feat['EXPANSION_NEXT_180D'].notna()].reset_index(drop=True)
y_exp = train_exp['EXPANSION_NEXT_180D'].astype(int)
exp_model = xgb.XGBClassifier(n_estimators=200, max_depth=3, learning_rate=0.05, subsample=0.8,
                              colsample_bytree=0.8, min_child_weight=3, random_state=RANDOM_STATE,
                              eval_metric='logloss')
exp_oof = grouped_oof(exp_model, train_exp[FEATURES], y_exp, train_exp['CUSTOMER_ID'])
exp_auc = roc_auc_score(y_exp, exp_oof)
exp_model.fit(train_exp[FEATURES], y_exp)
print(f'=== Expansion Propensity === training snapshots: {len(y_exp)}  positives: {y_exp.sum()}  '
      f'grouped 5-fold CV ROC AUC: {exp_auc:.3f}')

# %% [markdown]
# ## 9. Register all models in the Snowflake Model Registry

# %%
mv_maint = register(maint_model, 'BD_PREDICTIVE_MAINTENANCE', X_train.head(20),
                    'Random Forest: probability a component needs attention', {'roc_auc': maint_auc})
mv_rul = register(rul_model, 'BD_REMAINING_USEFUL_LIFE', Xr_train.head(20),
                  'Gradient Boosting: remaining useful life in days', {'mae_days': rul_mae, 'r2': rul_r2})
mv_churn = register(churn_model, 'BD_CHURN_RISK', X_c.head(20),
                    'XGBoost: probability of churn within 180 days', {'grouped_cv_roc_auc': churn_auc})
mv_health = register(health_model, 'BD_CUSTOMER_HEALTH_SCORE', X_c.head(20),
                     'XGBoost: customer health score 0-100', {'cv_mae': health_mae, 'cv_r2': health_r2})
mv_exp = register(exp_model, 'BD_EXPANSION_PROPENSITY', X_c.head(20),
                  'XGBoost: probability of expansion win within 180 days', {'grouped_cv_roc_auc': exp_auc})
print(registry.show_models()[['name', 'versions', 'default_version_name']].to_string(index=False))

# %% [markdown]
# ## 10. Batch-score customers with the registered models
#
# Scores come from `ModelVersion.run` in the warehouse. Top churn drivers come
# from XGBoost SHAP contributions (features pushing risk up).

# %%
score_input = session.create_dataframe(pd.concat([scoring[['CUSTOMER_ID']], X_c], axis=1))


def run_registered(mv, function_name, output_col):
    out = mv.run(score_input, function_name=function_name).to_pandas()
    return out.set_index('CUSTOMER_ID')[output_col]


churn_scores = run_registered(mv_churn, 'predict_proba', 'output_feature_1')
health_scores = run_registered(mv_health, 'predict', 'output_feature_0')
exp_scores = run_registered(mv_exp, 'predict_proba', 'output_feature_1')

contribs = churn_model.get_booster().predict(xgb.DMatrix(X_c), pred_contribs=True)[:, :-1]
drivers = []
for row in contribs:
    top = [FEATURES[i] for i in np.argsort(-row)[:3] if row[i] > 0]
    drivers.append(', '.join(FEATURE_LABELS[f] for f in top) if top else 'No significant risk drivers')

scores = pd.DataFrame({'CUSTOMER_ID': scoring['CUSTOMER_ID']})
scores['CHURN_RISK_SCORE'] = scores['CUSTOMER_ID'].map(churn_scores).astype(float).round(4)
scores['HEALTH_SCORE'] = scores['CUSTOMER_ID'].map(health_scores).astype(float).clip(0, 100).round(1)
scores['EXPANSION_PROPENSITY'] = scores['CUSTOMER_ID'].map(exp_scores).astype(float).round(4)
scores['CHURN_RISK_TIER'] = pd.cut(scores['CHURN_RISK_SCORE'], [-1, 0.3, 0.6, 2], labels=['Low', 'Medium', 'High']).astype(str)
scores['HEALTH_BAND'] = pd.cut(scores['HEALTH_SCORE'], [-1, 50, 75, 101], right=False, labels=['At Risk', 'Monitor', 'Healthy']).astype(str)
scores['EXPANSION_TIER'] = pd.cut(scores['EXPANSION_PROPENSITY'], [-1, 0.3, 0.6, 2], labels=['Low', 'Medium', 'High']).astype(str)
scores['TOP_RISK_DRIVERS'] = drivers
scores['MODEL_VERSION'] = MODEL_VERSION
scores['SCORED_AT'] = pd.Timestamp.utcnow().tz_localize(None)

cols = ['CUSTOMER_ID', 'CHURN_RISK_SCORE', 'CHURN_RISK_TIER', 'HEALTH_SCORE', 'HEALTH_BAND',
        'EXPANSION_PROPENSITY', 'EXPANSION_TIER', 'TOP_RISK_DRIVERS', 'MODEL_VERSION', 'SCORED_AT']
session.sql('TRUNCATE TABLE BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_SCORES').collect()
session.write_pandas(scores[cols], 'CUSTOMER_ML_SCORES', database='BD_INTELLIGENCE', schema='ANALYTICS',
                     auto_create_table=False, overwrite=False, use_logical_type=True)
print(f'Wrote {len(scores)} rows to ANALYTICS.CUSTOMER_ML_SCORES')

# %% [markdown]
# ## 11. Summary

# %%
summary = scoring[['CUSTOMER_ID', 'LIFECYCLE_STAGE']].merge(scores, on='CUSTOMER_ID')
print('=' * 70)
print('BOSTON DYNAMICS ML TRAINING SUMMARY')
print('=' * 70)
print(f'Predictive Maintenance  RF        test ROC AUC   {maint_auc:.3f}')
print(f'Anomaly Detection       Z-score   anomaly rate   {anomaly_rate:.1%}')
print(f'Remaining Useful Life   GBR       MAE {rul_mae:.1f} days, R2 {rul_r2:.3f}')
print(f'Churn Risk              XGBoost   grouped CV AUC {churn_auc:.3f}')
print(f'Customer Health Score   XGBoost   CV MAE {health_mae:.2f} pts, R2 {health_r2:.3f}')
print(f'Expansion Propensity    XGBoost   grouped CV AUC {exp_auc:.3f}')
print()
print(summary.groupby('LIFECYCLE_STAGE')[['CHURN_RISK_SCORE', 'HEALTH_SCORE', 'EXPANSION_PROPENSITY']].mean().round(3).to_string())
print()
print(summary['CHURN_RISK_TIER'].value_counts().to_string())
