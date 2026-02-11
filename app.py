import streamlit as st
import pandas as pd

st.set_page_config(page_title="Trading Journal")
st.title("My Trading Journal")

try:
    # This tells Python to look at your Excel file
    # We skip 8 rows because your headers are on Row 9
    df = pd.read_excel("JOURNAL.xlsm", sheet_name="Sheet1", skiprows=8)
    
    # This shows the data on your screen
    st.write("### Your Trade History")
    st.dataframe(df)

except Exception as e:
    st.error(f"Error loading file: {e}")