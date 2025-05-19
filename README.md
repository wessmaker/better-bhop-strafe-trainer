# better-bhop-trainer

### A better server side bhop strafe trainer for CS:S && CS:GO

> This plugin is a remastered version of the OG [strafe trainer](https://github.com/PaxPlay/bhop-strafe-trainer/) by PaxPlay

#### Features

- Prespeed indicator when client is on ground (max speed of 290u/s)
- 2 different positions for modern indicators
- 3 different strafe speed indicator styles
  - CLASSIC - The good old one which goes from left to right
  - SLIDER - Same as CLASSIC but direction depends on which way you are turning
  - TARGET - Same as SLIDER but uses "<>" as indicator

#### Usage

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

#### Developer notes

> Recommended to use mode 5 - TARGET_LOWER

> Feel free to create github issue to give suggestions for new features or styles because I will most likely add them

> And also special thanks to **YvngxChrig** for supplying the perfect prespeed angle value on sourcejump's discord server
