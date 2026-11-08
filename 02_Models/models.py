# models.py
#
# Purpose:
# - The six classifiers (D22, D25; Table S5), behind one
#   interface: make_model(name, seed, classes) returns an object with fit(X, y) and
#   predict(X); INPUT[name] says whether X are the window features ("features",
#   n x 26) or the window signals ("signals", n x 3 x samples, in g).
#   rf           scikit-learn RandomForestClassifier, defaults
#   lgbm         LightGBM LGBMClassifier, defaults, objective multiclass
#   cnn          1-D CNN of 01_CNN.py (3 conv blocks, 32-64-128 filters, dropout 0.25)
#   resnet       1-D ResNet of 02_ResNet.py (stem + 3 residual blocks, dropout 0.25)
#   hydra        aeon HydraClassifier, defaults
#   multirocket  aeon MultiRocketClassifier, defaults
# - cnn and resnet: channels standardized with the mean and SD of the
#   training windows, Adam (learning rate 1e-3, no weight decay), batch size 256,
#   30 epochs, no validation split and no early stopping, cross-entropy without class
#   weights. They run on the CPU (reproducible).
# - Predictions are made in chunks, so large test sets fit into memory.

from __future__ import annotations

import numpy as np

INPUT = {"rf": "features", "lgbm": "features", "cnn": "signals", "resnet": "signals",
         "hydra": "signals", "multirocket": "signals"}
MODEL_NAMES = list(INPUT)

# Settings of CNN and ResNet (Table S5)
BATCH_SIZE = 256
EPOCHS = 30
LEARNING_RATE = 1e-3
WEIGHT_DECAY = 0.0
DROPOUT = 0.25
PREDICT_CHUNK = 2000


def make_model(name: str, seed: int, classes: list[str]):
    if name == "rf":
        from sklearn.ensemble import RandomForestClassifier
        return RandomForestClassifier(random_state=seed, n_jobs=-1)
    if name == "lgbm":
        try:
            from lightgbm import LGBMClassifier
        except (ImportError, OSError) as exc:
            raise RuntimeError(f"LightGBM cannot be loaded ({exc}); on macOS run: brew install libomp") from exc
        return LGBMClassifier(objective="multiclass", random_state=seed, n_jobs=-1, verbosity=-1)
    if name in ("cnn", "resnet"):
        return TorchClassifier(name, seed, classes)
    if name in ("hydra", "multirocket"):
        return AeonClassifier(name, seed)
    raise ValueError(f"Unknown model {name}")


def predict_in_chunks(model, X: np.ndarray) -> np.ndarray:
    if len(X) == 0:
        return np.array([], dtype=str)
    chunk = getattr(model, "chunk", PREDICT_CHUNK)
    parts = [np.asarray(model.predict(X[i:i + chunk])).astype(str) for i in range(0, len(X), chunk)]
    return np.concatenate(parts)


# =========================================================
# aeon (HYDRA, MultiRocket)
# =========================================================
class AeonClassifier:
    def __init__(self, name: str, seed: int):
        try:
            from aeon.classification.convolution_based import HydraClassifier, MultiRocketClassifier
        except ImportError as exc:
            raise RuntimeError(f"aeon cannot be loaded ({exc}); install the requirements again") from exc
        cls = HydraClassifier if name == "hydra" else MultiRocketClassifier
        # Defaults; n_jobs only changes the speed.
        self.model = cls(random_state=seed, n_jobs=-1)
        # MultiRocket makes about 50 000 features per window: smaller prediction chunks.
        self.chunk = 500 if name == "multirocket" else PREDICT_CHUNK

    def fit(self, X: np.ndarray, y: np.ndarray):
        self.model.fit(X.astype(np.float64), y)
        return self

    def predict(self, X: np.ndarray) -> np.ndarray:
        return self.model.predict(X.astype(np.float64))


# =========================================================
# PyTorch (CNN, ResNet)
# =========================================================
def torch_modules():
    import torch
    from torch import nn

    class SimpleCNN(nn.Module):
        def __init__(self, n_classes: int, dropout: float):
            super().__init__()
            self.features = nn.Sequential(
                nn.Conv1d(3, 32, kernel_size=5, padding=2), nn.BatchNorm1d(32), nn.ReLU(), nn.MaxPool1d(2),
                nn.Conv1d(32, 64, kernel_size=5, padding=2), nn.BatchNorm1d(64), nn.ReLU(), nn.MaxPool1d(2),
                nn.Conv1d(64, 128, kernel_size=3, padding=1), nn.BatchNorm1d(128), nn.ReLU(), nn.AdaptiveAvgPool1d(1),
            )
            self.classifier = nn.Sequential(
                nn.Flatten(), nn.Dropout(dropout), nn.Linear(128, 64), nn.ReLU(), nn.Dropout(dropout),
                nn.Linear(64, n_classes),
            )

        def forward(self, x):
            return self.classifier(self.features(x))

    class ResidualBlock1D(nn.Module):
        def __init__(self, in_channels: int, out_channels: int, kernel_size: int, dropout: float):
            super().__init__()
            padding = kernel_size // 2
            self.conv1 = nn.Conv1d(in_channels, out_channels, kernel_size=kernel_size, padding=padding, bias=False)
            self.bn1 = nn.BatchNorm1d(out_channels)
            self.relu = nn.ReLU()
            self.dropout = nn.Dropout(dropout) if dropout > 0 else nn.Identity()
            self.conv2 = nn.Conv1d(out_channels, out_channels, kernel_size=kernel_size, padding=padding, bias=False)
            self.bn2 = nn.BatchNorm1d(out_channels)
            if in_channels != out_channels:
                self.shortcut = nn.Sequential(nn.Conv1d(in_channels, out_channels, kernel_size=1, bias=False),
                                              nn.BatchNorm1d(out_channels))
            else:
                self.shortcut = nn.Identity()

        def forward(self, x):
            identity = self.shortcut(x)
            out = self.dropout(self.relu(self.bn1(self.conv1(x))))
            out = self.bn2(self.conv2(out))
            return self.relu(out + identity)

    class TimeSeriesResNet(nn.Module):
        def __init__(self, n_classes: int, dropout: float):
            super().__init__()
            self.stem = nn.Sequential(nn.Conv1d(3, 64, kernel_size=7, padding=3, bias=False), nn.BatchNorm1d(64), nn.ReLU())
            self.blocks = nn.Sequential(
                ResidualBlock1D(64, 64, kernel_size=7, dropout=dropout),
                ResidualBlock1D(64, 128, kernel_size=5, dropout=dropout),
                ResidualBlock1D(128, 128, kernel_size=3, dropout=dropout),
            )
            self.pool = nn.AdaptiveAvgPool1d(1)
            self.classifier = nn.Sequential(nn.Flatten(), nn.Dropout(dropout), nn.Linear(128, n_classes))

        def forward(self, x):
            return self.classifier(self.pool(self.blocks(self.stem(x))))

    return torch, nn, {"cnn": SimpleCNN, "resnet": TimeSeriesResNet}


class TorchClassifier:
    def __init__(self, name: str, seed: int, classes: list[str]):
        try:
            self.torch, self.nn, archs = torch_modules()
        except ImportError as exc:
            raise RuntimeError(f"PyTorch cannot be loaded ({exc}); install the requirements again") from exc
        self.arch = archs[name]
        self.seed = seed
        self.classes = list(classes)
        self.device = self.torch.device("cpu")

    def fit(self, X: np.ndarray, y: np.ndarray):
        torch = self.torch
        torch.manual_seed(self.seed)
        np.random.seed(self.seed)
        torch.use_deterministic_algorithms(True, warn_only=True)
        X = X.astype(np.float32)
        self.mean = X.mean(axis=(0, 2), keepdims=True)
        std = X.std(axis=(0, 2), keepdims=True)
        self.std = np.where(std < 1e-8, 1.0, std).astype(np.float32)
        code = {c: i for i, c in enumerate(self.classes)}
        xt = torch.tensor((X - self.mean) / self.std, dtype=torch.float32)
        yt = torch.tensor([code[v] for v in y], dtype=torch.long)
        self.model = self.arch(n_classes=len(self.classes), dropout=DROPOUT).to(self.device)
        criterion = self.nn.CrossEntropyLoss()
        optimizer = torch.optim.Adam(self.model.parameters(), lr=LEARNING_RATE, weight_decay=WEIGHT_DECAY)
        generator = torch.Generator().manual_seed(self.seed)
        self.losses = []
        for _ in range(EPOCHS):
            self.model.train()
            order = torch.randperm(len(xt), generator=generator)
            total = 0.0
            for i in range(0, len(xt), BATCH_SIZE):
                idx = order[i:i + BATCH_SIZE]
                if len(idx) < 2:  # batch normalization needs at least two windows
                    continue
                optimizer.zero_grad()
                loss = criterion(self.model(xt[idx].to(self.device)), yt[idx].to(self.device))
                loss.backward()
                optimizer.step()
                total += float(loss.item()) * len(idx)
            self.losses.append(total / len(xt))
        return self

    def predict(self, X: np.ndarray) -> np.ndarray:
        torch = self.torch
        self.model.eval()
        xt = torch.tensor((X.astype(np.float32) - self.mean) / self.std, dtype=torch.float32)
        with torch.no_grad():
            pred = self.model(xt.to(self.device)).argmax(dim=1).cpu().numpy()
        return np.array(self.classes)[pred]
