# ⚔️ Boss Fight Simulator
Boss Battle Simulator game, where 3 classes of heroes fight a powerful boss with differing strategies.

<img width="1440" height="576" alt="ComfyUI_00113_" src="https://github.com/user-attachments/assets/31f9d98a-64e5-4a3d-b5ed-cbdbc5d78925" />

A turn-based tactical combat game built in Godot 4.

---

## 🎮 Installation & Running the Game

### 🪟 Windows
1. Download and extract the **Windows** `.zip` from the [Latest Release](../../releases).
2. Run `Boss_Fight_Sim.exe`.
3. (Optional) Keep the .pak bundled in the folder!

### 🍎 macOS
1. Download and extract the **macOS** `.zip` from the [Latest Release](../../releases).
2. Move `Boss_Fight_Sim.app` to your **Applications** folder.
3. **First-Time Launch (Bypassing Gatekeeper):**
   * Right-click (or `Ctrl + Click`) on `Boss_Fight_Sim.app`.
   * Select **Open** from the menu.
   * Click **Open** again in the security prompt window.  
   *(You only need to do this once! Future launches work via normal double-click).*

Alternatively Mac users are free to pay for the 100 dollar subscription license it would cost me to bypass this, but for a free poorly made minigame I think you can jump this hurdle.

### 🐧 Linux
1. Download and extract the **Linux** `.zip` from the [Latest Release](../../releases).
2. Make the executable runnable: `chmod +x Boss_Fight_Sim.x86_64`
3. Launch via terminal: `./Boss_Fight_Sim.x86_64`

---

## ✨ Recent Updates (v1.2.0 Overhaul)

* **Fighter Class Stance System**
  * Dynamically switch between **BERSERK**, **GUARD**, and **BALANCED** stances based on BP (Battle Points) debt.
  * Real-time status UI updates reflect active damage/defense multipliers.
* **Mage Class Mana System**
  * Resource management introduced with a Max MP pool of **100**.
  * Spells now require specific MP costs to cast.
  * Turn-start passive MP regeneration added!
