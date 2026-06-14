from darts.models import TFTModel
import joblib

model_nse = TFTModel.load(
    "models/tft_nse/2026-01-30_04_51_16_torch_model_run_3909/_model.pth.tar"
)

model_bse = TFTModel.load(
    "models/tft_bse/2026-01-30_05_08_57_torch_model_run_3909/_model.pth.tar"
)

scaler_nse = joblib.load("models/scaler_nse.pkl")
scaler_bse = joblib.load("models/scaler_bse.pkl")

print("✅ DARTS TFT MODELS LOADED (ARCH + WEIGHTS)")
