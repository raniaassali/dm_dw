import pandas as pd

# Step 1: Extract
file_path = 'hotel_bookings.csv'
df = pd.read_csv(file_path)
# Step 2: Transform
# Remove duplicate rows
df.drop_duplicates(inplace=True)

# Replace missing values in 'children' with 0
df.fillna({'children': 0}, inplace=True)

# Remove rows with missing 'hotel' or 'arrival_date_year'
df.dropna(subset=['hotel', 'arrival_date_year'], inplace=True)

# Create a new column 'total_guests'
df['total_guests'] = df['adults'] + df['children'] + df['babies']

# Combine date columns into a single datetime column
df['arrival_date'] = pd.to_datetime(
    df['arrival_date_year'].astype(int).astype(str) + '-' +
    df['arrival_date_month'] + '-' +
    df['arrival_date_day_of_month'].astype(int).astype(str),
    format='%Y-%B-%d',
    errors='coerce'
)

# Drop rows where date conversion failed
df.dropna(subset=['arrival_date'], inplace=True)

# Remove the now redundant date columns
df.drop(columns=['arrival_date_year', 'arrival_date_month', 'arrival_date_day_of_month'], inplace=True)

# Step 3: Load into CSV
output_file_path = 'hotel_bookings_cleaned1.csv'
df.to_csv(output_file_path, index=False)

print(f"✅ Saved cleaned data to '{output_file_path}'")
