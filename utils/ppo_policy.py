def ppo_decision(current_price, predicted_price, trend):
    """
    Minimal RL-inspired decision logic
    """

    if predicted_price > current_price and trend == "UP":
        return "BUY"
    elif predicted_price < current_price and trend == "DOWN":
        return "SELL"
    else:
        return "HOLD"
