import tensorflow_datasets as tfds
import tensorflow as tf
import matplotlib.pyplot as plt
from tf_keras.layers import Dense, Conv2D, MaxPooling2D, Flatten, Dropout
from tf_keras.models import Sequential
from tf_keras.optimizers import Adam
from tf_keras.callbacks import EarlyStopping
import numpy as np
import os

# Load dataset with full info (not supervised)
dataset, info = tfds.load('oxford_iiit_pet', with_info=True)

train_data = dataset['train']
test_data = dataset['test']

#Preprocess function
def preprocess(example):
    image = example['image']
    label = example['species']   
    image = tf.image.resize(image, [150, 150])
    image = tf.cast(image, tf.float32) / 255.0
    return image, label

train_data = train_data.map(preprocess).shuffle(1000).batch(32).prefetch(tf.data.AUTOTUNE)
test_data = test_data.map(preprocess).batch(32).prefetch(tf.data.AUTOTUNE)

#Visualization
'''for images, labels in train_data.take(1):
    plt.imshow(images[0])
    plt.title("Cat" if labels[0].numpy() == 0 else "Dog")
    plt.axis("off")
    plt.show()'''


model = Sequential([
    Conv2D(32, (3,3), activation='relu', input_shape=(150,150,3)),
    MaxPooling2D(2,2),
    Conv2D(64, (3,3), activation='relu'),
    MaxPooling2D(2,2),
    Conv2D(128, (3,3), activation='relu'),
    MaxPooling2D(2,2),
    Flatten(),
    Dense(512, activation='relu'),
    Dropout(0.5),
    Dense(1, activation='sigmoid')  
])

model.compile(
    optimizer=Adam(learning_rate=0.0001),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

#early_stop = EarlyStopping(monitor="val_loss", patience=3, restore_best_weights=True)

history = model.fit(
    train_data,
    validation_data=test_data,
    epochs=20,
    #callbacks= [early_stop]
)


def quantize(x, scale=256):
    return np.round(x * scale).astype(np.int16)  

def save_hex(filename, array):
    if os.path.exists(filename):
        print(f"Skipped {filename}, file already exists.")
        return

    with open(filename, "w") as f:
        for val in array.flatten(): 
            hex_val = format(np.uint16(val), "04X")
            f.write(f"{hex_val}\n")
    print(f"Saved {filename}")

for i, layer in enumerate(model.layers):
    params = layer.get_weights()  
    if len(params) == 0:
        continue

    W, b = params
    W_q = quantize(W)
    b_q = quantize(b)

    save_hex(f"layer{i+1}_w.mem", W_q)
    save_hex(f"layer{i+1}_b.mem", b_q)

    print(f"Saved layer {i+1} -> W: {W_q.shape}, b: {b_q.shape}")


if os.path.exists('cat_vs_dog_saved_model'):
        print(f"Skipped 'cat_vs_dog_saved_model', file already exists.")
else:
    tf.saved_model.save(model, export_dir='./cat_vs_dog_saved_model')
