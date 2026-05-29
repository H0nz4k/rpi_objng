# Touchscreen profily

## 3M USB – ověřená cesta

Zařízení `3M 3M USB Touchscreen - EX II`, USB `0596:0001`, používá ověřenou matici `0 -1 1 -1 0 1`.

```bash
sudo touch-preset apply
sudo reboot
kalibrace
```

## eGalaxTouch / EETI

Zařízení bylo rozpoznáno jako `eGalaxTouch Virtual Device for Single` s `Calibration: n/a` a `Capabilities: pointer`. Proto se na něj automaticky nepoužívá libinput matice; použije se oficiální EETI/eGalax kalibrace.
