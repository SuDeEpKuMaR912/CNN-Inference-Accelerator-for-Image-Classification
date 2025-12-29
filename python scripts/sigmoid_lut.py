import numpy as np

x = np.linspace(-8, 8, 64)
y = 1 / (1 + np.exp(-x))
y_q8_8 = np.round(y * 256).astype(int)

with open("sigmoid_lut.mem", "w") as f:
    for val in y_q8_8:
        f.write(f"{val:04X}\n")

print("Generated sigmoid_lut.mem with 64 entries (Q8.8).")

