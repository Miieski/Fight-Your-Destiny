RIG FAMILIES (segmented rigs: one mesh per joint, origin on the joint; names = Motor6D names in Studio)
======================================================================================================
Every family is built once in code (tools/blender/fyd_creatures.py: Model.part(name, parent, joint)) and reused by
all the models of the family with their own shapes, palette and size. The clips of each family are in
tools/blender/fyd_creature_clips.py (Luau twin: Config/RigClips). Reference size = the size the clip offsets are
written for (the game scales them by size / reference).

Family      Ref size  Joints (parent)                                                     Used by
Quadruped   3         Body; Head, LegFL, LegFR, LegBL, LegBR, Tail (Body)                boar, wolves, bears, jackal,
                                                                                         crocodile, jaguars, foxes, ibex
Biped       5.5       Torso; Head, ArmL, ArmR, LegL, LegR (Torso); weapons in ArmR/ArmL  bandits, pirate, archers,
                                                                                         skeleton, mummy, tribals, knights,
                                                                                         monkey, yeti, trolls, NPCs
BossBiped   17        same as Biped (+ Intro / Enrage, two-handed Attack1)               Cursed Pharaoh, Frost King
Gorilla     18        Body; Head, ArmL, ArmR, LegL, LegR (Body)                          Ancestral Gorilla
Bird        3         Body; Head, WingL, WingR, Tail, LegL, LegR (Body)                  seagull, bat, vulture, eagles
Serpent     6 (long)  Seg1; Head (Seg1), Seg2 (Seg1), Seg3 (Seg2) ... Seg6               sand snake, green snake
Arachnid    4.5       Body; Abdomen, LegL1-4, LegR1-4, ArmL, ArmR (Body); Tail (Abdomen) spiders, scorpion
Crustacean  4         Body; ArmL, ArmR (claws), LegL1-3, LegR1-3 (Body)                  giant crab
Insect      4         Body; Head, LegL1-3, LegR1-3 (Body)                                giant scarab
Fish        2.5       Body; Tail, FinL, FinR, Jaw (Body)                                 piranha, swordfish
Amphibian   3.5       Body; Head, LegFL, LegFR, LegBL, LegBR (Body)                      toxic frog
Golem       8         Body; Head, ArmL, ArmR, LegL, LegR (Body)                          golems, animated statue, Golem boss
Snowman     5         Body; Middle (Body); Head, ArmL, ArmR (Middle)                     cursed snowman
Floater     4         Body; Tail (Body), Tail2 (Tail), ArmL, ArmR (Body)                 ice spirit, sandstorm djinn

Pets use the family of their animal (Quadruped, Bird, Fish, Serpent, Amphibian, Insect, Biped, Floater) with the
Idle clip only. Joint names are case-sensitive and must stay identical to Lib/EnemyRigs (the placeholders).
