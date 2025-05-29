import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from imblearn.over_sampling import SMOTE
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
import matplotlib.pyplot as plt
from sklearn.metrics import roc_curve
from sklearn.pipeline import Pipeline
from joblib import dump


# Charger les données
df = pd.read_csv("D:/booking.csv")

# Supprimer les colonnes inutiles
colonnes_a_supprimer = ['reservation_status', 'reservation_status_date', 'agent', 'company', 
                       'assigned_room_type', 'reserved_room_type']
df = df.drop(columns=colonnes_a_supprimer, errors='ignore')

# Gérer les valeurs manquantes
df['children'] = df['children'].fillna(0)
df['country'] = df['country'].fillna('Unknown')

# Ajouter des variables simples
df['total_stays'] = df['stays_in_weekend_nights'] + df['stays_in_week_nights']
df['total_guests'] = df['adults'] + df['children'] + df['babies']
df['total_previous_bookings'] = df['previous_cancellations'] + df['previous_bookings_not_canceled']

# Regrouper les pays rares
country_counts = df['country'].value_counts()
rare_countries = country_counts[country_counts < 100].index
df['country'] = df['country'].apply(lambda x: 'Other' if x in rare_countries else x)

# Définir les colonnes numériques et catégoriques
numeric_features = ['lead_time', 'stays_in_weekend_nights', 'stays_in_week_nights', 
                   'adults', 'children', 'babies', 'previous_cancellations', 
                   'previous_bookings_not_canceled', 'booking_changes', 
                   'days_in_waiting_list', 'adr', 'required_car_parking_spaces', 
                   'total_of_special_requests', 'total_stays', 'total_guests', 
                   'total_previous_bookings']
categorical_features = ['hotel', 'meal', 'country', 'market_segment', 
                      'distribution_channel', 'deposit_type', 'customer_type']

# Séparer les variables et la cible
X = df[numeric_features + categorical_features]
y = df['is_repeated_guest']

# Diviser en entraînement (80%) et test (20%)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# Afficher les tailles et la répartition
print("Taille entraînement :", X_train.shape, y_train.shape)
print("Taille test :", X_test.shape, y_test.shape)
print("Répartition de is_repeated_guest (entraînement) :\n", y_train.value_counts(normalize=True))

# Créer le préprocesseur
preprocessor = ColumnTransformer(
    transformers=[
        ('num', StandardScaler(), numeric_features),
        ('cat', OneHotEncoder(handle_unknown='ignore'), categorical_features)
    ])

# Définir les modèles
rf_model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
lr_model = LogisticRegression(random_state=42, max_iter=1000)

# Afficher un message pour confirmer
print("Modèles définis : Random Forest et Logistic Regression.")

# Appliquer SMOTE pour équilibrer les classes dans l’entraînement
smote = SMOTE(random_state=42)
X_train_transformed = preprocessor.fit_transform(X_train)
X_train_resampled, y_train_resampled = smote.fit_resample(X_train_transformed, y_train)

# Transformer les données de test
X_test_transformed = preprocessor.transform(X_test)

# Entraîner et évaluer Random Forest
print("\n=== Évaluation de Random Forest ===")
rf_model.fit(X_train_resampled, y_train_resampled)
y_pred_rf = rf_model.predict(X_test_transformed)
print("Classification Report (Random Forest) :")
print(classification_report(y_test, y_pred_rf))
print("AUC-ROC (Random Forest) :", roc_auc_score(y_test, rf_model.predict_proba(X_test_transformed)[:, 1]))
print("Matrice de confusion (Random Forest) :")
print(confusion_matrix(y_test, y_pred_rf))


# Entraîner et évaluer Logistic Regression
print("\n=== Évaluation de Logistic Regression ===")
lr_model.fit(X_train_resampled, y_train_resampled)
y_pred_lr = lr_model.predict(X_test_transformed)
print("Classification Report (Logistic Regression) :")
print(classification_report(y_test, y_pred_lr))
print("AUC-ROC (Logistic Regression) :", roc_auc_score(y_test, lr_model.predict_proba(X_test_transformed)[:, 1]))
print("Matrice de confusion (Logistic Regression) :")
print(confusion_matrix(y_test, y_pred_lr))

# Courbe ROC pour Random Forest
y_prob_rf = rf_model.predict_proba(X_test_transformed)[:, 1]
fpr, tpr, _ = roc_curve(y_test, y_prob_rf)
plt.figure()
plt.plot(fpr, tpr, label=f'Random Forest (AUC = {roc_auc_score(y_test, y_prob_rf):.2f})')
plt.plot([0, 1], [0, 1], 'k--')
plt.xlabel('Taux de faux positifs')
plt.ylabel('Taux de vrais positifs')
plt.title('Courbe ROC - Random Forest')
plt.legend()
plt.savefig('D:/courbe_roc_rf.png')
plt.close()

# Importance des variables pour Random Forest
feature_names = (numeric_features + 
                 preprocessor.named_transformers_['cat'].get_feature_names_out(categorical_features).tolist())
importances = rf_model.feature_importances_
feature_importance = pd.DataFrame({'Variable': feature_names, 'Importance': importances})
top_features = feature_importance.sort_values(by='Importance', ascending=False).head(10)
plt.figure()
plt.barh(top_features['Variable'], top_features['Importance'])
plt.xlabel('Importance')
plt.title('Top 10 des variables importantes - Random Forest')
plt.savefig('D:/importance_variables_rf.png')
plt.close()

# Afficher un message pour confirmer
print("Graphiques générés : courbe ROC et importance des variables pour Random Forest.")

# Créer un pipeline intégrant le préprocesseur et le modèle
rf_pipeline = Pipeline([
    ('preprocessor', preprocessor),
    ('model', RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42))
])

# Entraînement avec SMOTE
X_train_resampled, y_train_resampled = smote.fit_resample(
    preprocessor.fit_transform(X_train), y_train
)

# Entraîner le pipeline
rf_pipeline.fit(X_train, y_train)

# Sauvegarder le modèle et le préprocesseur
dump(rf_pipeline, 'D:/rf_pipeline.joblib')

# Visualisation améliorée des importances
top_features = feature_importance.sort_values(by='Importance', ascending=False).head(10)
plt.figure(figsize=(10, 6))
plt.barh(top_features['Variable'], top_features['Importance'], color='skyblue')
plt.xlabel('Importance')
plt.title('Top 10 des variables importantes - Random Forest')
plt.tight_layout()  # Évite les chevauchements de texte
plt.savefig('D:/importance_variables_rf.png', dpi=300, bbox_inches='tight')