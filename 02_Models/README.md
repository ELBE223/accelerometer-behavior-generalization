# 02_Models

The six classifiers (Methods 2.2; Table S5), behind one interface in `models.py`:
`make_model(name, seed, classes)` returns an object with `fit(X, y)` and `predict(X)`.

| Key | Classifier | Input | Implementation |
|---|---|---|---|
| `rf` | Random Forest | 26 window features (dynamic acceleration) | scikit-learn, defaults |
| `lgbm` | LightGBM | 26 window features | LightGBM, defaults |
| `cnn` | 1-D CNN (3 conv blocks) | window signals (3 × 50, in g) | PyTorch; 30 epochs, Adam, lr 0.001, batch 256, dropout 0.25 |
| `resnet` | 1-D ResNet (3 residual blocks) | window signals | PyTorch; as CNN |
| `hydra` | HYDRA | window signals | aeon, defaults |
| `multirocket` | MultiRocket | window signals | aeon, defaults |

CNN and ResNet standardize the channels with the mean and SD of the training windows, have
no validation split or early stopping, and run on the CPU for reproducibility. Settings
follow the theses (D22, D25). Training and evaluation are in `03_Evaluation/`.
