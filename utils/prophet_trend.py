from prophet import Prophet
import pandas as pd

def get_trend(df: pd.DataFrame) -> str:
    """
    df must have columns: date, close
    """

    p_df = df.rename(columns={
        "date": "ds",
        "close": "y"
    })

    model = Prophet(daily_seasonality=True)
    model.fit(p_df)

    future = model.make_future_dataframe(periods=30)
    forecast = model.predict(future)

    slope = forecast["yhat"].iloc[-1] - forecast["yhat"].iloc[-30]

    if slope > 0:
        return "UP"
    elif slope < 0:
        return "DOWN"
    else:
        return "SIDEWAYS"
