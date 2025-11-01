# 🚀 FPGA-Based CNN Inference Accelerator  
###  *Image Classification using Verilog & Fixed-Point Arithmetic*

This project implements a **Convolutional Neural Network (CNN) accelerator on FPGA** for image classification (Cats vs Dogs) — inspired by modern edge-AI architectures.

✅ Trained CNN in Python (TensorFlow)  
✅ Extracted & Quantized weights to **Q8.8 fixed-point**  
✅ Implemented all layers in **Verilog RTL**  
✅ Simulated and verified in **Xilinx Vivado**  

---

## 🎯 Objective
Accelerate CNN inference using **hardware parallelism** and **fixed-point arithmetic** on FPGA, enabling lightweight real-time edge AI.

---

## 🧠 CNN Model Architecture (Trained in TensorFlow)

| Layer | Details |
|------|--------|
Input | 150×150×3 RGB |
Conv2D | 32 filters, 3×3, ReLU |
MaxPool | 2×2 |
Conv2D | 64 filters, 3×3, ReLU |
MaxPool | 2×2 |
Conv2D | 128 filters, 3×3, ReLU |
MaxPool | 2×2 |
Flatten | — |
Dense | 512 → ReLU |
Dense | 1 → Sigmoid |

Weights exported → **Quantized to Q8.8** → Stored in `.mem`.

---

## 🔧 RTL Hardware Modules

| Module | Function | Uses |
|--------|---------|-----|
`qadd.v` | Q8.8 addition | — |
`qmult.v` | Q8.8 multiplication | — |
`variable_shift_reg.v` | Pipelining buffer | — |
`comparator.v` | Compares values | — |
`max_reg.v` | Stores max value | comparator |
`line_buffer.v` | Sliding 3×3 window | shift regs |
`relu.v` | ReLU activation | comparator |
`pooler_max2x2.v` | Max pooling | max_reg |
`flatten.v` | 2D → 1D | — |
`mac_manual.v` | Multiply-Accumulate | qmult + qadd |
`dense.v` | Fully-connected | mac_manual |
`sigmoid_lut.v` | Sigmoid via LUT | — |
`input_mux.v` | Selects input source | — |
`control_logic.v` | Controls CNN pipeline | — |
`accelerator.v` | **Top module** | all modules |

---

## 🧮 Fixed-Point Format

| Parameter | Meaning |
|----------|--------|
Format | Q8.8 |
Scale | ×256 |
Range | −128 to +127.996 |
Reason | Faster, low-resource inference on FPGA |

Example conversion (Python):

```python
pixel_q8 = int(round(pixel * 256))
hex_val = format(pixel_q8 & 0xFFFF, "04X")

