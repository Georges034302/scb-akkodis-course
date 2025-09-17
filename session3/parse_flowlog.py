import json
import pandas as pd

with open("flowlog.json") as f:
    data = json.load(f)

rows = []
for record in data["records"]:
    for flow in record["flowRecords"]["flows"]:
        for group in flow["flowGroups"]:
            rule = group.get("rule")
            for tuple_str in group["flowTuples"]:
                tuple_fields = tuple_str.split(",")
                rows.append([
                    record["time"],          # Date/Time
                    record["category"],      # eventtype
                    rule,                    # rule
                    tuple_fields[5],         # protocol
                    tuple_fields[4],         # port (dest_port)
                    tuple_fields[1],         # srcIP
                    tuple_fields[2],         # destIP
                    tuple_fields[7],         # action
                ])

columns = [
    "Date/Time", "eventtype", "rule", "protocol", "port", "srcIP", "destIP", "action"
]

df = pd.DataFrame(rows, columns=columns)

allow_df = df[df["action"].isin(["A", "B", "E"])]
deny_df = df[df["action"] == "D"]

def print_centered_headers(df):
    # Calculate column widths
    col_widths = [max(len(str(x)) for x in [col] + df[col].astype(str).tolist()) for col in df.columns]
    # Print centered headers
    header = " | ".join([str(col).center(width) for col, width in zip(df.columns, col_widths)])
    print(header)
    print("-+-".join(['-' * width for width in col_widths]))
    # Print left-aligned rows
    for _, row in df.iterrows():
        print(" | ".join([str(val).ljust(width) for val, width in zip(row, col_widths)]))

print("=== ALLOWED TRAFFIC ===")
if not allow_df.empty:
    print_centered_headers(allow_df)
else:
    print("No allowed traffic found.")

print("\n=== DENIED TRAFFIC ===")
if not deny_df.empty:
    print_centered_headers(deny_df)
else:
    print("No denied traffic found.")