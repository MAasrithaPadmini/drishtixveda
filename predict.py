from pytorch_forecasting import TemporalFusionTransformer
import glob

def load_latest_model(path):
    ckpt = glob.glob(f"{path}/checkpoints/*.ckpt")[0]
    return TemporalFusionTransformer.load_from_checkpoint(ckpt)

model_nse = load_latest_model("models/tft_nse")
model_bse = load_latest_model("models/tft_bse")

def predict(model, data):
    return model.predict(data)
