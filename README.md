# better-bhop-strafe-trainer

### A better server side bhop strafe trainer for CS:S && CS:GO

> This plugin is a remastered version of the OG [strafe trainer](https://github.com/PaxPlay/bhop-strafe-trainer/) by PaxPlay

### Features

- General improvements

  - 5 indicator modes
  - Improved indicator responsiveness
  - Refactored codebase to remove unnecessary and slow code
  - Added perfect prespeed indicator

- Perfect prespeed indicator

  - Indicates how close the client's turn angle is to the perfect turn angle to get max 290u/s prespeed
  - Active when client is on ground
  - Extremely accurate and works on every indicator mode
  - [Demo video](https://www.youtube.com/watch?v=Itg-NgfPNAU)

- Strafe speed indicator
- Indicates how close the client's turn angle is to the perfect turn angle for given speed
- 2 different positions for modern indicators
- 3 different strafe speed indicator styles
  - CLASSIC - The good old one which goes from left to right
  - SLIDER - Same as CLASSIC but direction depends on which way you are turning
  - TARGET - Same as SLIDER but uses "<>" as indicator
  - [Demo video](https://www.youtube.com/watch?v=nBEFEU2gIcY)

---

### Usage

Once installed type following to console

```cmd
sm_strafetrainer <mode>
```

| Mode | Name         |
| ---- | ------------ |
| 1    | CLASSIC      |
| 2    | SLIDER_UPPER |
| 3    | SLIDER_LOWER |
| 4    | TARGET_UPPER |
| 5    | TARGET_LOWER |

> Note that at the moment of writing this the command has to be executed every time client reconnects or map changes due to bug which will be fixed once I have time

---

### Demo video links (youtube)

[Different strafe trainer modes](https://www.youtube.com/watch?v=nBEFEU2gIcY)

[Prespeed indicator](https://www.youtube.com/watch?v=Itg-NgfPNAU)

---

### Developer notes

> It's recommended to use mode 1 (CLASSIC) or 5 (TARGET_LOWER)

> Feel free to create github issue to give suggestions for new features or styles because I will most likely add them if I have time

> And also special thanks to **YvngxChrig** for supplying the perfect prespeed angle value on sourcejump discord server
