"""Chapters 5, 10 (isometric) and 12 (third-person finale). Imported by gen3d_levels.py."""
import math

from tscn3d import Scene, level_header, xform

PI = math.pi


def _player_rig(sc, pos, state=1, rig=None):
    sc.node("Player", None, ".", {"transform": xform(pos), "state": str(state)}, instance="player")
    sc.node("CameraRig", None, ".", dict(rig or {}), instance="rig")


def _decor(sc):
    return lambda *a, **k: sc.block(*a, parent="Decor", kind="decor", **k)


def _prop(sc):
    """Solid furniture/props (collide like walls) kept under Decor."""
    return lambda *a, **k: sc.block(*a, parent="Decor", **k)


def _shell(sc, x1, z1, h, floor=True, ceiling=None, near_low=None):
    """Room shell. near_low: the camera-side walls (S and E, isometric) are only this
    tall in solid wall, with lab glass above so they never hide the room."""
    B = sc.block
    if floor:
        B("Floor", (-0.5, -1, -0.5), (x1 + 0.5, 0, z1 + 0.5))
    B("WallN", (-0.5, 0, -0.5), (x1 + 0.5, h, 0))
    B("WallW", (-0.5, 0, 0), (0, h, z1))
    if near_low is None:
        B("WallS", (-0.5, 0, z1), (x1 + 0.5, h, z1 + 0.5))
        B("WallE", (x1, 0, 0), (x1 + 0.5, h, z1))
    else:
        B("WallS", (-0.5, 0, z1), (x1 + 0.5, near_low, z1 + 0.5))
        B("WallE", (x1, 0, 0), (x1 + 0.5, near_low, z1))
        B("GlassS", (-0.5, near_low, z1 + 0.1), (x1 + 0.5, h, z1 + 0.3), kind="glass")
        B("GlassE", (x1 + 0.1, near_low, 0), (x1 + 0.3, h, z1), kind="glass")
    if ceiling is not None:
        B("Ceiling", (-0.5, ceiling, -0.5), (x1 + 0.5, ceiling + 0.5, z1 + 0.5))


# =============================================================================
# Chapter 5 - Pressure (cryo, isometric)
# =============================================================================
def level_05():
    sc = Scene()
    level_header(sc, "5 - Pressure", "cryo", 3, {"kill_y": "-6.0", "fog_scale": "0.12", "ambient_boost": "1.4"}, sun_rot=(-1.0, 0.7, 0))
    B = sc.block
    _shell(sc, 16, 12, 10.5, ceiling=10, near_low=1.2)
    # Mid deck with the cracked section (left half)
    B("DeckW", (6, 3, 0), (7.5, 3.5, 7))
    B("DeckE", (10.5, 3, 0), (11, 3.5, 7))
    B("DeckN", (7.5, 3, 0), (10.5, 3.5, 2.5))
    B("DeckS", (7.5, 3, 5.5), (10.5, 3.5, 7))
    B("CrackedFloor", (7.5, 3, 2.5), (10.5, 3.5, 5.5), kind="breakable")
    B("DeckPostA", (6, 0, 6.6), (6.4, 3, 7), look="dark")
    B("DeckPostB", (10.6, 0, 6.6), (11, 3, 7), look="dark")
    # Partition between the cold side and the upper (goal) floor
    B("Partition", (11, 5, 0), (11.4, 10, 12))
    B("UpperW", (11.4, 4.5, 0), (13, 5, 12))
    B("UpperE", (15, 4.5, 0), (16, 5, 12))
    B("UpperN", (13, 4.5, 0), (15, 5, 2))
    B("UpperS", (13, 4.5, 4), (15, 5, 12))
    B("UpperPost", (11, 0, 11.4), (11.4, 4.5, 12), look="dark")
    B("CryoPod1", (0.4, 0, 0.4), (2.2, 2.6, 2.2), look="fill")
    B("CryoPod2", (2.6, 0, 0.4), (4.4, 2.6, 2.2), look="fill")
    B("Crate", (12.2, 0, 9.0), (13.6, 1.2, 10.6), look="dark")

    Z = sc.zone
    Z("Heat", (5, 1.5, 8.5), (2, 3, 2), "heat")
    Z("Freeze", (9, 8.25, 4), (2.4, 3.5, 2.4), "freeze")
    Z("Fan", (14, 3.5, 3), (1.9, 7, 1.9), "fan")
    Z("Goal", (14, 6.0, 9.0), (2, 2, 2), "goal")

    sc.plate("IcePlate", (9, 0, 4), (2.0, 2.0), "hatch")
    sc.gate("FanHatch", (14, 4.75, 3), (2, 0.5, 2), (0, 0, 2.4), "hatch", 0.7)

    D = _decor(sc)
    S = _prop(sc)
    S("PodGlass1", (0.6, 0.3, 2.2), (2.0, 2.3, 2.3), look="glow", tint=(0.45, 0.85, 1.0))
    S("PodGlass2", (2.8, 0.3, 2.2), (4.2, 2.3, 2.3), look="glow", tint=(0.45, 0.85, 1.0))
    D("FrostRug", (6.8, 0, 2.8), (11.2, 0.02, 5.2), look="glow", tint=(0.35, 0.6, 0.8))
    D("WarnHatch", (12.8, 5.0, 1.8), (15.2, 5.02, 4.2), look="glow", tint=(0.9, 0.7, 0.15))
    S("Console", (0, 0, 5.0), (0.9, 1.2, 7.5), look="dark")
    D("ConsoleScr", (0.9, 0.7, 5.2), (0.95, 1.1, 7.3), look="glow", tint=(0.4, 0.9, 1.0))
    S("Bench", (12.0, 5.0, 10.6), (15.8, 5.9, 11.6), look="dark")
    S("ShelfTop", (6.2, 3.5, 6.0), (7.4, 4.4, 6.9), look="dark")
    D("Icicle1", (7.6, 9.6, 0.1), (7.8, 10, 0.3), look="glow", tint=(0.7, 0.9, 1.0), passable=True)
    sc.pipe("PipeCold", (5.5, 9.6, 0.35), 11, "x", 0.18, color=(0.6, 0.75, 0.9))
    sc.pipe("PipeFreeze", (9, 9.6, 4), 0.8, "y", 0.3, color=(0.6, 0.75, 0.9))
    sc.pipe("PipeUp", (0.35, 5, 11.6), 10, "y", 0.16)
    sc.pipe("PipeUpper", (13.7, 9.6, 11.6), 4.6, "x", 0.15)
    sc.jet("ColdMist", (3.5, 2.6, 1.3), height=1.0, period=3.5, burst=1.4)
    sc.jet("HeatPuff", (5, 0.05, 8.5), height=3.0, period=2.2, burst=1.0)

    L = sc.lamp
    L("LampCold", (3, 4.5, 4), (0.6, 0.85, 1.0), 1.6, 9.0)
    L("LampDeck", (9, 2.6, 6.5), (0.6, 0.85, 1.0), 1.0, 6.0, fitting=1, tube=2.0)
    L("LampUpper", (13.5, 8.5, 7), (1.0, 0.9, 0.7), 1.4, 8.0)
    L("LampUnder", (13.5, 4.1, 7.5), (0.8, 0.9, 1.0), 1.1, 7.0, fitting=1, tube=2.0)

    H = sc.hint
    H("Hint1", (5, 3.6, 8.5), "Hot zones force STEAM")
    H("Hint2", (9, 6.0, 5.6), "Cold zones force ICE")
    H("Hint3", (9, 1.6, 6.0), "Ice is heavy: press the plate")
    H("Hint4", (14, 1.9, 5.0), "Fans blow gas upward")

    _player_rig(sc, (2, 0.4, 10), 1, {"iso_size": "13.0"})
    return sc


# =============================================================================
# Chapter 10 - Momentum (boiler, isometric)
# =============================================================================
def level_10():
    sc = Scene()
    level_header(sc, "10 - Momentum", "boiler", 3, {"kill_y": "-6.0", "max_y": "5.6", "fog_scale": "0.12", "ambient_boost": "1.7"}, sun_rot=(-1.0, 0.8, 0))
    B = sc.block
    _shell(sc, 18, 14, 6, near_low=1.2)
    B("Step1", (0.5, 0, 8.5), (3.5, 1.2, 10.5))
    B("Step2", (0.5, 0, 6.5), (3.5, 2.4, 8.5))
    B("Deck", (0, 0, 0), (6, 3.6, 6.5))
    B("Runway", (6, 0, 0.5), (13, 3.6, 4.5))
    B("Strip", (15.2, 0, 0), (18, 1.2, 14))
    B("CrackedWall", (15.2, 1.2, 7), (18, 3.6, 7.4), kind="breakable", break_speed=8.0)
    B("Boiler", (4.0, 0, 11.0), (5.8, 3.0, 13.8))

    Z = sc.zone
    Z("FloorSpikes", (10.6, 0.4, 7.0), (9.2, 0.8, 14.0), "spikes")
    Z("RunwaySpikes", (9.75, 4.0, 2.5), (6.5, 0.8, 3.0), "spikes")
    Z("Goal", (16.6, 2.3, 12.6), (2, 2, 2), "goal")

    sc.plate("IcePlate", (16.6, 1.2, 8.7), (2.2, 1.0), "exit")
    sc.gate("ExitShutter", (16.6, 2.4, 10.6), (2.8, 2.4, 0.3), (0, -2.45, 0), "exit", 0.35)

    D = _decor(sc)
    S = _prop(sc)
    D("Firebox", (3.95, 0.4, 11.6), (4.0, 1.4, 13.2), look="glow", tint=(1.0, 0.45, 0.12))
    D("Gauge", (3.95, 2.0, 12.2), (4.0, 2.4, 12.6), look="glow", tint=(1.0, 0.85, 0.5))
    S("RailN", (6, 3.6, 0.5), (13, 3.9, 0.62), look="metal", tint=(0.75, 0.55, 0.3), shadow=False)
    S("RailS", (6, 3.6, 4.38), (13, 3.9, 4.5), look="metal", tint=(0.75, 0.55, 0.3), shadow=False)
    D("RunStripe", (0.5, 3.6, 2.4), (13, 3.62, 2.6), look="glow", tint=(1.0, 0.75, 0.15))
    D("PitGlow", (6, 0, 4.2), (15.2, 0.05, 14), look="glow", tint=(0.5, 0.12, 0.03))
    S("Chute", (13.0, 3.3, 0.5), (13.3, 3.6, 4.5), look="metal", tint=(0.8, 0.5, 0.25))
    S("CrateA", (15.4, 1.2, 0.2), (16.4, 2.2, 1.2), look="dark")
    S("CrateB", (15.25, 1.2, 4.8), (16.05, 2.0, 5.7), look="dark")
    sc.pipe("PipeN", (9, 5.4, 0.35), 18, "x", 0.22)
    sc.pipe("PipeUp1", (6.3, 3.0, 0.25), 6, "y", 0.2, color=(0.7, 0.5, 0.25))
    sc.pipe("PipeUp2", (13.3, 3.0, 0.25), 6, "y", 0.2, color=(0.7, 0.5, 0.25))
    sc.jet("PitSteam1", (9, 0.1, 8), height=2.5, period=2.5, burst=1.0)
    sc.jet("PitSteam2", (12.5, 0.1, 11), height=2.5, period=3.1, burst=1.0, phase=1.2)
    sc.jet("BoilerValve", (4.9, 3.0, 12.4), height=1.6, period=3.5, burst=1.0)

    L = sc.lamp
    L("PitGlowL", (10.5, 1.0, 8.5), (1.0, 0.45, 0.15), 1.8, 8.0, fitting=2, flicker=0.25)
    L("DeckLamp", (3, 5.4, 3), (1.0, 0.8, 0.55), 1.4, 8.0)
    L("StripLamp", (16.6, 4.6, 6), (1.0, 0.8, 0.55), 1.4, 8.0)
    L("StartLamp", (3, 3.6, 11), (1.0, 0.7, 0.4), 1.2, 7.0, fitting=1, tube=2.0)

    H = sc.hint
    H("Hint1", (2.0, 2.6, 11.4), "Hop up (SPACE)")
    H("Hint2", (3.0, 5.2, 3.2), "Build up speed as ICE (Q)")
    H("Hint3", (16.6, 4.4, 5.2), "Fast ICE smashes cracked walls")
    H("Hint4", (10.5, 1.8, 10.5), "Fell short? R restarts")

    _player_rig(sc, (2, 0.4, 12.5), 1, {"iso_size": "13.5"})
    return sc


# =============================================================================
# Chapter 12 - Meltdown (rooftop, third person finale)
# =============================================================================
def level_12():
    sc = Scene()
    level_header(sc, "12 - Meltdown", "rooftop", 0, {"kill_y": "-8.0", "max_y": "9.4", "fog_scale": "0.6", "metadata/open_sky": "true"},
                 sun_rot=(-0.75, 0.75, 0), shadows=True)
    B = sc.block
    P = (0.55, 0.6, 0.7)
    # --- Roof A (start) -----------------------------------------------------
    B("RoofA", (0, -20, 0), (10, 0, 10))
    B("ParapetAN", (0, 0, -0.3), (10, 0.6, 0), look="dark")
    B("ParapetAS", (0, 0, 10), (10, 0.6, 10.3), look="dark")
    B("ParapetAW", (-0.3, 0, -0.3), (0, 0.6, 10.3), look="dark")
    B("StairHut", (0.4, 0, 0.4), (3.4, 3.0, 3.2))
    B("StairHutRoof", (0.2, 3.0, 0.2), (3.6, 3.25, 3.4), look="metal", tint=P)
    B("ACUnitA", (6.0, 0, 7.6), (8.4, 1.3, 9.4), look="fill")
    # --- Roof B with the shed ---------------------------------------------------
    B("RoofB", (12.5, -20, 0), (24, 0, 10))
    B("ParapetBN", (12.5, 0, -0.3), (16, 0.6, 0), look="dark")
    B("ParapetBS", (12.5, 0, 10), (16, 0.6, 10.3), look="dark")
    B("ShedN", (16, 0, 0), (24, 9.5, 0.4))
    B("ShedS", (16, 0, 9.6), (24, 9.5, 10))
    B("ShedE1", (23.6, 0, 0.4), (24, 9.5, 4))
    B("ShedE2", (23.6, 0, 6), (24, 9.5, 9.6))
    B("ShedE3", (23.6, 2.5, 4), (24, 9.5, 6))
    B("ShedW1", (16, 0, 0.4), (16.4, 9.5, 3))
    B("ShedW2", (16, 0, 7), (16.4, 9.5, 9.6))
    B("ShedW3", (16, 0, 3), (16.4, 5, 7))
    B("ShedMidW", (16.4, 3, 0.4), (17.5, 3.5, 9.6))
    B("ShedMidE", (20.5, 3, 0.4), (23.6, 3.5, 9.6))
    B("ShedMidN", (17.5, 3, 0.4), (20.5, 3.5, 3.5))
    B("ShedMidS", (17.5, 3, 6.5), (20.5, 3.5, 9.6))
    B("CrackedFloor", (17.5, 3, 3.5), (20.5, 3.5, 6.5), kind="breakable")
    B("ShedRoof", (15.8, 9.5, -0.2), (24.2, 10, 10.2), look="metal", tint=P)
    B("Awning", (13.4, 9.5, 2.5), (15.8, 9.8, 7.5), look="metal", tint=(0.6, 0.45, 0.35))
    # --- Corridor bridge to roof C ---------------------------------------------
    B("CorridorFloor", (24, -1, 3.6), (27.4, 0, 6.4))
    B("CorridorN", (24, 0, 3.6), (27.4, 2.5, 4))
    B("CorridorS", (24, 0, 6), (27.4, 2.5, 6.4))
    B("CorridorRoof", (24, 2.5, 3.6), (27.4, 2.9, 6.4), look="metal", tint=P)
    B("GrateWall", (26.9, 0, 4), (27.3, 2.5, 6), kind="grate")
    # --- Roof C, gantry, roof D ------------------------------------------------
    B("RoofC", (27.4, -20, 0), (36, 0, 10))
    B("ParapetCN", (27.4, 0, -0.3), (36, 0.6, 0), look="dark")
    B("ParapetCS", (27.4, 0, 10), (36, 0.6, 10.3), look="dark")
    B("Gantry", (31, 7.5, 1.5), (44, 8, 8.5), look="metal", tint=(0.4, 0.42, 0.5))
    B("RoofD", (42, -20, 0), (50, 1.5, 10))
    B("ParapetDN", (42, 1.5, -0.3), (49.4, 2.1, 0), look="dark")
    B("ParapetDS", (42, 1.5, 10), (49.4, 2.1, 10.3), look="dark")
    B("Billboard", (49.4, 1.5, -0.3), (50, 9.6, 10.3), look="dark")

    Z = sc.zone
    Z("ExhaustVent", (14.5, 1.2, 5), (1.8, 2.4, 2.6), "heat")
    Z("ChamberSpikes", (20, 0.4, 5), (7.2, 0.8, 9.2), "spikes")
    Z("RoofVent", (29.5, 1.2, 5), (2.0, 2.4, 2.6), "heat")
    Z("Crosswind", (37.75, 2.9, 5), (3.4, 14.5, 6), "fan", rot=(0, 0, -PI / 2), extra={"push_strength": "56.0"})
    Z("GantrySpikes", (37.5, 7.0, 5), (11, 1.0, 6.6), "spikes", rot=(0, 0, PI))
    Z("Goal", (46.5, 2.7, 5), (2.4, 2.2, 2.4), "goal")

    sc.plate("ChamberPlate", (19, 0, 5), (1.8, 1.8), "corridor")
    sc.gate("CorridorShutter", (23.8, 1.25, 5), (0.3, 2.5, 2), (0, 2.6, 0), "corridor", 0.6)

    D = _decor(sc)
    S = _prop(sc)
    # Roof A props
    D("HutDoor", (3.4, 0, 1.2), (3.45, 2.2, 2.4), look="metal", tint=(0.35, 0.4, 0.5))
    D("HutSign", (3.45, 2.3, 1.4), (3.5, 2.7, 2.2), look="glow", tint=(0.4, 1.0, 0.5))
    D("ACFan", (6.6, 1.3, 8.0), (7.8, 1.35, 9.0), look="metal", tint=(0.25, 0.28, 0.35))
    S("TowerLegs", (5.2, 0, 1.2), (5.5, 4.0, 1.5), look="metal", tint=(0.3, 0.3, 0.38))
    S("TowerLegs2", (7.5, 0, 1.2), (7.8, 4.0, 1.5), look="metal", tint=(0.3, 0.3, 0.38))
    S("TowerLegs3", (5.2, 0, 3.5), (5.5, 4.0, 3.8), look="metal", tint=(0.3, 0.3, 0.38))
    S("TowerLegs4", (7.5, 0, 3.5), (7.8, 4.0, 3.8), look="metal", tint=(0.3, 0.3, 0.38))
    S("WaterTank", (4.9, 4.0, 0.9), (8.1, 6.8, 4.1), look="fill", tint=(0.8, 0.7, 0.65))
    S("WaterTankCap", (5.3, 6.8, 1.3), (7.7, 7.3, 3.7), look="metal", tint=(0.4, 0.35, 0.35))
    D("AlleyGlow1", (10, -8, 0), (12.5, -7.9, 10), look="glow", tint=(0.25, 0.2, 0.45), passable=True)
    # Shed + roof B
    # Exhaust vent grille, flush enough to roll onto (the heat zone draws the grill).
    D("VentBox", (13.6, 0, 3.6), (15.4, 0.1, 6.4), look="metal", tint=(0.6, 0.35, 0.25), passable=True)
    D("ShedSign", (20.5, 7.6, -0.05), (23.2, 8.6, 0.0), look="glow", tint=(1.0, 0.3, 0.45))
    D("ShedSign2", (16.8, 7.6, 10.0), (19.5, 8.6, 10.05), look="glow", tint=(0.4, 0.8, 1.0))
    D("ChamberGlow", (16.5, 0, 0.5), (23.5, 0.03, 9.5), look="glow", tint=(0.35, 0.1, 0.12))
    D("AlleyGlow2", (24, -8, 0), (27.4, -7.9, 10), look="glow", tint=(0.25, 0.2, 0.45), passable=True)
    # Roof C + gantry
    # Crosswind fan intake: a grate (steam blows through it, ICE can't).
    sc.block("ACHousing", (30.3, 0, 1.6), (30.7, 5.0, 8.4), kind="grate", parent="Decor")
    S("GantryPostA", (31, 0, 1.5), (31.3, 7.5, 1.8), look="metal", tint=(0.35, 0.36, 0.45))
    S("GantryPostB", (31, 0, 8.2), (31.3, 7.5, 8.5), look="metal", tint=(0.35, 0.36, 0.45))
    S("GantryPostC", (43.7, 1.5, 1.5), (44, 7.5, 1.8), look="metal", tint=(0.35, 0.36, 0.45))
    S("GantryPostD", (43.7, 1.5, 8.2), (44, 7.5, 8.5), look="metal", tint=(0.35, 0.36, 0.45))
    D("GantryLights", (31.5, 7.45, 4.9), (43.5, 7.5, 5.1), look="glow", tint=(1.0, 0.4, 0.3))
    D("AlleyGlow3", (36, -8, 0), (42, -7.9, 10), look="glow", tint=(0.25, 0.2, 0.45), passable=True)
    # Roof D: helipad + billboard art
    D("Helipad", (44.6, 1.5, 3.1), (48.4, 1.53, 6.9), look="glow", tint=(0.3, 0.9, 0.5))
    D("HelipadInner", (45.1, 1.53, 3.6), (47.9, 1.55, 6.4), look="metal", tint=(0.15, 0.16, 0.2))
    D("BillboardFace", (49.35, 3.0, 0.5), (49.4, 8.8, 9.5), look="glow", tint=(0.22, 0.1, 0.38))
    D("BillboardBand", (49.3, 5.4, 0.5), (49.35, 6.4, 9.5), look="glow", tint=(0.9, 0.6, 0.25))
    D("BillboardDrop1", (49.3, 6.8, 2.0), (49.35, 8.2, 3.2), look="glow", tint=(0.3, 0.55, 1.0))
    D("BillboardDrop2", (49.3, 6.8, 6.8), (49.35, 8.2, 8.0), look="glow", tint=(0.3, 0.55, 1.0))
    D("BillboardFrame", (49.3, 2.8, 0.3), (49.35, 3.0, 9.7), look="metal", tint=(0.3, 0.3, 0.38))
    sc.pipe("PipeA", (5, 0.25, 9.7), 10, "x", 0.16)
    sc.pipe("PipeB", (14.2, 0.25, 0.3), 3.5, "x", 0.16)
    sc.pipe("PipeShed", (16.1, 5, 0.25), 10, "y", 0.14, color=(0.6, 0.45, 0.35))
    sc.pipe("PipeC", (31.5, 0.25, 9.7), 8, "x", 0.18)
    sc.pipe("Antenna", (2, 5.5, 1.8), 5, "y", 0.05, color=(0.5, 0.5, 0.6))
    sc.jet("ShedSteam", (14.5, 0.4, 5), height=2.5, period=2.0, burst=1.0)
    sc.jet("RoofSteam", (29.5, 0.4, 5), height=2.5, period=2.4, burst=1.0, phase=0.8)
    sc.jet("ACSteam", (7.2, 1.4, 8.5), height=1.2, period=4.0, burst=1.5)

    sc.node("Rain", "CPUParticles3D", "Decor", {}, script="rain")
    sc.node("Skyline", "MultiMeshInstance3D", "Decor", {"transform": xform((25, 0, 5))}, script="skyline")

    L = sc.lamp
    L("HutLamp", (3.6, 2.6, 1.8), (0.5, 1.0, 0.6), 1.2, 6.0)
    L("ChamberLamp", (20, 2.6, 5), (1.0, 0.4, 0.45), 1.4, 7.0, flicker=0.25)
    L("AtticLamp", (20, 9.2, 5), (0.9, 0.85, 1.0), 1.2, 8.0, fitting=1, tube=3.0)
    L("CorridorLamp", (25.7, 2.3, 5), (0.6, 0.8, 1.0), 1.0, 5.0, fitting=1, tube=1.6)
    L("GantryLamp", (37.5, 7.2, 5), (1.0, 0.45, 0.35), 1.6, 10.0, fitting=2)
    L("HeliLamp", (46.5, 3.0, 5), (0.4, 1.0, 0.6), 1.0, 7.0, fitting=2)
    L("BillboardLamp", (48.6, 6.0, 5), (0.7, 0.5, 1.0), 1.6, 9.0, fitting=2)

    H = sc.hint
    H("Hint1", (8.0, 1.9, 5), "One last shift. Use everything.")
    H("Hint2", (14.5, 3.2, 5), "Exhaust vent: up and in")
    H("Hint3", (20.0, 7.2, 5), "Freeze over the crack")
    H("Hint4", (29.0, 3.6, 5), "Ride the crosswind. Mind the gantry!")

    _player_rig(sc, (5.0, 0.4, 5.5), 1, {"yaw_deg": "-90.0", "distance": "5.0"})
    return sc
