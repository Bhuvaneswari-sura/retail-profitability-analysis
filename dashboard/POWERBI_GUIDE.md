# Power BI Dashboard: Build Guide

One-page report built on `data/processed/superstore_clean.csv`. It takes about 45–60 minutes in Power BI Desktop (free from the Microsoft Store).

## 1. Load the data
1. **Home → Get data → Text/CSV** → choose `data/processed/superstore_clean.csv` → **Transform Data**.
2. In Power Query, check the column types: `order_date`, `ship_date` and `order_month` = **Date**; `sales`, `profit`, `discount`, `list_price_sales` = **Decimal number**; `is_loss` = **True/False**.
3. Rename the query to **orders** → **Close & Apply**.

## 2. Date table
**Modeling → New table**:
```DAX
Dates =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2014, 1, 1 ), DATE ( 2017, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month", FORMAT ( [Date], "MMM" ),
    "Month No", MONTH ( [Date] )
)
```
- Mark it as a date table: **Table tools → Mark as date table → Date**.
- In **Model view**, drag `Dates[Date]` onto `orders[order_date]` to create the relationship.
- Sort `Month` by `Month No`.

## 3. Measures
Create a blank table to hold the measures (**Home → Enter data** → name it `_Measures`), then add each one with **New measure**:

```DAX
Total Sales = SUM ( orders[sales] )

Total Profit = SUM ( orders[profit] )

Profit Margin % = DIVIDE ( [Total Profit], [Total Sales] )

Orders = DISTINCTCOUNT ( orders[order_id] )

Profit per Order = DIVIDE ( [Total Profit], [Orders] )

Loss-Making Lines % =
DIVIDE (
    CALCULATE ( COUNTROWS ( orders ), orders[is_loss] = TRUE () ),
    COUNTROWS ( orders )
)

Sales PY = CALCULATE ( [Total Sales], SAMEPERIODLASTYEAR ( Dates[Date] ) )

Sales YoY % = DIVIDE ( [Total Sales] - [Sales PY], [Sales PY] )
```

Format `Profit Margin %`, `Loss-Making Lines %` and `Sales YoY %` as **Percentage**, and the money measures as **Currency ($)**.

## 4. What-if slider: discount cap
This is the standout feature. Managers drag a slider and see the profit they would recover.

1. **Modeling → New parameter → Numeric range**. Name it `Discount Cap`, set Min 0, Max 0.8, Increment 0.05, Default 0.2, and tick **Add slicer to this page**.
2. Add these measures:
```DAX
Profit with Cap =
SUMX (
    orders,
    IF (
        orders[discount] > [Discount Cap Value],
        orders[profit] + orders[list_price_sales] * ( 1 - [Discount Cap Value] ) - orders[sales],
        orders[profit]
    )
)

Profit Recovered = [Profit with Cap] - [Total Profit]
```
*Assumption (state it on the page):* volume holds at the capped discount, so this is the best case.

## 5. Page layout
| Area | Visual | Fields |
|---|---|---|
| Top row | 5 **Cards** | Total Sales, Total Profit, Profit Margin %, Orders, Loss-Making Lines % |
| Left, middle | **Line chart** | X: `Dates[Date]` (Year → Month hierarchy). Y: Total Sales |
| Right, middle | **Clustered bar chart** | Y: `sub_category`. X: Total Profit. Sort ascending. Conditional colour: red when below 0 |
| Left, bottom | **Clustered column chart** | X: `discount_band`. Y: Profit Margin % |
| Right, bottom | **Filled map** (or bar chart) | Location: `state`. Colour saturation: Total Profit (diverging, centre 0) |
| Side panel | **Slicers** | `Dates[Year]`, `region`, `segment`, `category` + the Discount Cap slider |
| Next to slider | 2 **Cards** | Profit with Cap, Profit Recovered |

**Design tips:** use one accent colour (blue) for normal values and one warning colour (orange or red) for losses. Write the title as the insight (e.g. *"Discounts above 20% lose money"*). Leave white space between visuals.

## 6. Save and publish
- Save the report as `dashboard/retail_profitability.pbix`.
- Export a screenshot (**File → Export → PDF**, or a Windows screenshot) to `images/dashboard.png`, and add it to the top of the README.
- Optional: **Publish → Power BI Service** (free with a university account) and put the public link in the README and on your CV.
