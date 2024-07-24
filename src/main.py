import os
import sys
import json
import requests
import logging
import pandas as pd
from typing import Dict

logging.basicConfig(level=logging.INFO)

TICKER = "DJT"
AV_API_KEY = os.getenv('AV_API_KEY')
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL")
DONNY_SHARES = 80_000_000

def make_request():
    url = f"https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={TICKER}&apikey={AV_API_KEY}"
    resp = requests.get(url)

    if resp.status_code != 200:
        logging.error(f"Request failed with status code <{resp.status_code}>.")
        sys.exit(1)
    else:
        if resp.json() != {}:
            data = resp.json()
        else:
            logging.error(f"Empty response content.")
            sys.exit(1)
    return resp.json()


def build_df(data: Dict) -> pd.DataFrame:
    """
    Build a Pandas DataFrame from the provided data dictionary containing time series daily data.

    Args:
        data (Dict): A dictionary containing time series daily data, typically retrieved from an API response.

    Returns:
        pd.DataFrame: A Pandas DataFrame representing the time series data with columns for date, datetime,
                      open, high, low, close, and volume.
    """
    df_data = data.get('Time Series (Daily)', None)

    if not df_data:
        logging.error("Time Series Data absent from response content.")
        sys.exit(1)

    df = pd.DataFrame(df_data)
    df = df.transpose().head(31)
    df.columns = [i.split(' ')[1] for i in df.columns]
    df = df.reset_index(names='date')
    df.insert(loc=1, column="datetime", value=pd.to_datetime(df['date']))
    numeric_columns = ['open', 'high', 'low', 'close', 'volume']
    df[numeric_columns] = df[numeric_columns].apply(pd.to_numeric)
    
    return df


def ts_delta(input_df, beg: int, end: int) -> float:
    """Calculate the time series delta between two specified rows in the input DataFrame.

    Args:
        input_df (DataFrame): The input DataFrame containing time series data.
        beg (int): The index of the beginning row.
        end (int): The index of the ending row.

    Returns:
        float: The time series delta between the closing values of the specified rows,
               rounded to two decimal places.
    """
    delta = round(input_df.iloc[end].close - input_df.iloc[beg].close, 2)
    delta = int(delta)
    ret_dict = dict(
        abs_val=abs(delta) * DONNY_SHARES,
        val_dir = "-" if delta < 0 else "",
        chart_dir = "downwards" if delta < 0 else "upwards"
    )
    return ret_dict


def format_delta(df: pd.DataFrame) -> str:
    """Calculate the weekly percentage delta between the first and last rows in the input DataFrame.

    Args:
        df (DataFrame): The input DataFrame containing time series data.

    Returns:
        str: A formatted string representing the weekly percentage delta, rounded to two decimal places.
    """
    weekly_pct_delta_num = round(((df.iloc[0]['close'] - df.iloc[6]['close']) / abs(df.iloc[6]['close'])) * 100, 2)
    if weekly_pct_delta_num > 0:
        weekly_pct_delta_str = f"+{abs(weekly_pct_delta_num)}%"
    elif weekly_pct_delta_num < 0:
        weekly_pct_delta_str = f"-{abs(weekly_pct_delta_num)}%"
    else:
        weekly_pct_delta_str = f"{abs(weekly_pct_delta_num)}%"
    return weekly_pct_delta_str


def get_quote() -> str:
    """Retrieve a random quote from the Tronald Dump API.

    Returns:
        str: A random quote from the Tronald Dump API.
    """
    td_url = "https://api.tronalddump.io/random/quote"
    headers = {"Accept": "application/hal+json"}
    resp = requests.get(td_url, headers=headers)
    quote_val = resp.json().get('value')

    return quote_val


def post_to_slack(**kwargs) -> None:
    """Posts a message to a Slack channel containing daily, weekly, and monthly deltas.

    Returns:
        None
    """

    slack_msg = f"""
    <https://www.google.com/finance/quote/DJT:NASDAQ?hl=en|*How's Donny Doin'?*>

`Weekly ∆: {kwargs['weekly_pct_delta']}`

*Quote of the Day*
> {kwargs['qotd']}
"""
    slack_payload = {
        "text": slack_msg
    }
    response = requests.post(SLACK_WEBHOOK_URL, data=json.dumps(slack_payload))
    if response.status_code == 200:
        logging.info("Message posted successfully to Slack")
    else:
        logging.error(f"Failed to post message to Slack: {response.text}")


def main(message, context) -> None:
    stock_data = make_request()
    df = build_df(stock_data)
    post_to_slack(weekly_pct_delta=format_delta(df), qotd=get_quote())
