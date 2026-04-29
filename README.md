# 🕯️ THE THRONE THAT BREATHES

A dark fantasy 2D roguelike built in Godot.

A card-and-dice driven journey through a dying world, where the player walks toward a throne that should not exist.

---

## ⚔️ CORE CONCEPT

You are not a hero.

You are someone who did not stop.

The world is already broken.
At its center sits a throne that breathes, sustaining a king who refused to die.

Your goal is simple:

* Reach the capital
* End the throne

---

## 🎮 GAME STRUCTURE

### 🧭 Overworld

* Free movement between locations
* Travel rolls
* Encroaching Rot system

### 🏚️ Locations

* Side-view exploration
* Branching decisions (3–6 per location)
* Risk/reward structure

### ⚔️ Combat

* Card + Dice system
* Assign dice to cards to perform actions

---

## 🧱 CORE STAT SYSTEM

The game uses a **lean, decision-focused stat system** designed to support card + dice gameplay.

### Core Stats

* **HP (Health)**
  Determines survivability

* **Dice Count**
  Number of dice rolled per turn (primary resource)

* **Power**
  Increases damage dealt

* **Guard**
  Reduces incoming damage

* **Control**
  Affects dice manipulation and consistency

* **Luck**
  Influences rare outcomes and events

### Philosophy

* Stats support decisions, not replace them
* Complexity comes from dice + cards
* Avoid redundant systems (mana, stamina, crit stats)

---

## 🧠 DATA-DRIVEN ARCHITECTURE

**Resources = Data**
**Scripts/Scenes = Behavior**

This allows scalable and maintainable design.

---

## 📂 PROJECT STRUCTURE

```
res://
  scripts/
    combat/
      Combatant.gd
      PlayerCombatant.gd
      EnemyCombatant.gd
      CharacterStats.gd
      CardData.gd

  resources/
    characters/
    enemies/
    cards/

  scenes/
    combat/
```

---

## 🧩 CORE DATA OBJECTS

### CharacterStats (Resource)

```
max_hp
dice_count
power
guard
control
luck
```

Used by both players and enemies.

---

### CharacterClass (Resource)

Defines playable archetypes:

* Starting stats
* Starting deck
* Starting relics

---

### EnemyData (Resource)

Defines enemies:

* Stats
* Card pool
* Behavior patterns

### Design Note

Enemies behave like players:

* Use cards
* Use dice
* Follow simplified AI logic

---

### CardData (Resource)

Defines card behavior:

* Dice requirements
* Effects (damage, guard, draw, etc.)

---

## ⚔️ COMBAT ENTITY SYSTEM

### Combatant (Base Class)

Shared logic for all combat participants:

* HP management
* Damage resolution
* Guard handling

### PlayerCombatant

* Deck, hand, discard
* Player control

### EnemyCombatant

* AI logic
* Card selection

---

## 🎲 SYSTEM DESIGN PRINCIPLE

Players and enemies follow the same rules:

* Same dice system
* Same card system
* Differences come from data and behavior

---

## 🔥 DEVELOPMENT PRIORITY

1. CharacterStats
2. CardData
3. CharacterClass
4. EnemyData
5. Combatant system
6. Player + Enemy logic

---

## 📌 FINAL NOTE

Do not hardcode characters or enemies.

Use **Resources (.tres)** for all data.

This ensures:

* Flexibility
* Scalability
* Clean architecture

---

## 🗺️ DEVELOPMENT ROADMAP

The project follows a **combat-first vertical slice approach**. Systems are built in layers, with each stage unlocking the next.

---

### ✅ COMPLETED — Milestone: Playable Combat Core

**Goal:** A fully playable, satisfying combat loop.

#### Completed:

* `CharacterStats.gd`
* `Combatant.gd` base combat logic
* `PlayerCombatant.gd` and `EnemyCombatant.gd`
* Dice rolling, assigning, and spending
* CardData-driven cards
* Multiple enemies in combat
* Manual target selection
* Ally/enemy targeting rules
* Slot-based attacks such as Cleave
* Enemy intents
* HP, guard, damage, and death handling
* Combatant status UI
* Floating damage / guard feedback
* Victory and defeat states
* Basic reward placeholder

#### Current Combat Feel:

* Fights are tense and lethal
* Win/loss rate is close to even
* Winning often leaves the player near death
* Dice + card decisions feel meaningful

#### Success Criteria:

* Player can complete a full combat encounter
* Combat feels responsive and understandable
* Dice + card interaction is engaging

---

### 🔴 NOW — Milestone: Run Structure Prototype

**Goal:** Connect combat encounters into a tiny playable run loop.

#### Tasks:

* Create `RunTest.tscn`
* Add a simple route/node selection screen
* Create 3 test nodes:
  * Basic combat
  * Event / risk-reward choice
  * Hard combat or boss-lite encounter
* Carry player HP between encounters
* Add post-combat reward choices
* Add simple card reward flow
* Add basic healing/rest reward option
* Return to route screen after each node

#### Success Criteria:

* Player can complete a short 3-node run
* Combat tension carries across encounters
* Rewards meaningfully affect later fights
* The player feels pressure from HP attrition
* The game starts to feel like a roguelike, not just a combat test

---

### 🟠 NEXT — Milestone: World Structure & Flow

**Goal:** Replace the temporary run test with actual exploration structure.

#### Tasks:

* Create node/location system
* Implement side-view location exploration
* Add branching decisions within locations
* Build overworld map or route map
* Implement location entry roll system
* Add 2–3 fully playable locations, such as:
  * cave
  * village outskirts
  * ruined shrine
  * corpse road

#### Success Criteria:

* Player can move between locations
* Locations contain meaningful decisions
* Combat is triggered naturally from exploration
* The run has a beginning, middle, and endpoint

---

### 🟡 LATER — Milestone: World Depth & Narrative

**Goal:** Expand the world and player experience.

#### Tasks:

* Implement towns, shops, NPCs, and services
* Add minimalist event-driven dialogue
* Create branching event system
* Expand enemy variety and behaviors
* Add relics and progression systems
* Balance combat, healing, and economy
* Add Rot pressure across the run

#### Success Criteria:

* Player experiences a full run loop: explore → fight → choose → progress
* World feels reactive and cohesive
* Narrative is delivered through events, enemies, and tone

---

### 🔵 FINAL PHASE — Milestone: Expansion & Polish

**Goal:** Refine and expand systems.

#### Tasks:

* Add new character archetypes
* Expand card pool
* Add advanced dice mechanics, such as cursed, cracked, or mutated dice
* Improve UI/UX
* Add audio and visual polish
* Add more enemies, bosses, and locations

#### Success Criteria:

* Systems feel cohesive and intentional
* Game supports replayability
* Strong identity and atmosphere

---

## 📌 DEVELOPMENT STRATEGY

* Build vertically (complete one system before expanding)
* Prioritize feel over feature count
* Test constantly with small playable loops

> If combat is not fun, nothing else will matter.

---
