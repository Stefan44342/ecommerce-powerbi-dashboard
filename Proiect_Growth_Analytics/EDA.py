import pandas as pd

filepath="online_retail.csv"
df=pd.read_csv(filepath,encoding="ISO-8859-1")
print(df.head())
df.info()
print(df.isnull().sum())
print(df.columns)
print("------------------------------------------------------------------")
df=df.dropna(subset=['CustomerID'])
df=df[~df["InvoiceNo"].astype(str).str.startswith("C")]
df=df[df["Quantity"]>0]
df=df[df["UnitPrice"]>0]
df["TotalRevenue"]=df["Quantity"]*df["UnitPrice"]
df['InvoiceDate']=pd.to_datetime(df["InvoiceDate"])
df['YearMonth']=df['InvoiceDate'].dt.to_period("M").astype(str)
df["dayOfTheWeek"]=df["InvoiceDate"].dt.day_name()
df["Hour"]=df["InvoiceDate"].dt.hour
df.to_csv("Online_retail_cleaned.csv",index=False)
print(df.columns)
