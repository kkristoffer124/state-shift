"""Generates levels/level_XX_3d.tscn (3, 5, 6, 8, 10, 12) as real-node scenes.
   python -I tools/levelgen/gen3d_levels.py [05 10 ...]"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tscn3d import Scene, level_header, xform, v3  # noqa: E402

ROOT = r"C:/Users/krist/OneDrive/Documents/state-shift/levels"
PI = math.pi


def player_rig(sc, pos, state=1, rig=None):
    sc.node("Player", None, ".", {"transform": xform(pos), "state": str(state)}, instance="player")
    sc.node("CameraRig", None, ".", dict(rig or {}), instance="rig")


def decor(sc):
    return lambda *a, **k: sc.block(*a, parent="Decor", kind="decor", **k)


def prop(sc):
    """Solid furniture/props (collide like walls) kept under Decor."""
    return lambda *a, **k: sc.block(*a, parent="Decor", **k)


def flask(sc, name, a, b, fluid, fill=0.6):
    """Glass vessel (solid lab glass) with a glowing liquid inside."""
    sc.block(name, a, b, kind="glass", parent="Decor")
    i = 0.03
    top = a[1] + (b[1] - a[1]) * fill
    sc.block(name + "Fluid", (a[0] + i, a[1] + 0.01, a[2] + i), (b[0] - i, top, b[2] - i),
             parent="Decor", kind="decor", look="glow", tint=fluid, shadow=False)


# =============================================================================
# Chapter 3 - Rise (lab, third person)
# =============================================================================
def level_03():
    sc = Scene()
    sc.y_from, sc.y_add = 3.0, 1.0   # lab rooms are 4.5 m tall (room for the 3rd-person camera)
    level_header(sc, "3 - Rise", "lab", 0, {"kill_y": "-6.0"}, sun_rot=(-1.05, 0.6, 0))
    B = sc.block
    # Shell 14 x 13 x 10
    B("Floor", (-1, -1, -1), (15, 0, 11))
    B("WallW", (-1, 0, -1), (0, 13, 11))
    B("WallE", (14, 0, -1), (15, 13, 11))
    B("WallN", (0, 0, -1), (14, 13, 0))
    B("WallS", (0, 0, 10), (14, 13, 11))
    B("Ceiling", (-1, 13, -1), (15, 14, 11))
    # Room A ceiling with Grate1
    B("CeilA_W", (0, 3.5, 0), (5, 4, 10))
    B("CeilA_E", (7, 3.5, 0), (8, 4, 10))
    B("CeilA_N", (5, 3.5, 0), (7, 4, 1))
    B("CeilA_S", (5, 3.5, 3), (7, 4, 10))
    B("Grate1", (5, 3.5, 1), (7, 4, 3), kind="grate")
    # Divider between the lab rooms and the atrium: wainscot, glass, beam, glass
    B("DividerLow", (8, 0, 0), (8.5, 1, 10))
    B("DividerGlassLow", (8.1, 1, 0), (8.4, 3.5, 10), kind="glass")
    B("DividerBeam", (8, 3.5, 0), (8.5, 4, 10))
    B("DividerGlassHigh", (8.1, 4, 0), (8.4, 8, 10), kind="glass")
    # Mezzanine ceiling with Grate2 (far corner)
    B("Mezz_E", (3, 8, 0), (8.5, 8.5, 10))
    B("Mezz_W", (0, 8, 0), (1, 8.5, 10))
    B("Mezz_N", (1, 8, 0), (3, 8.5, 7))
    B("Mezz_S", (1, 8, 9), (3, 8.5, 10))
    B("Grate2", (1, 8, 7), (3, 8.5, 9), kind="grate")
    # Bench to hop in room A
    B("Bench", (0, 0, 4.6), (8, 0.9, 5.4), look="fill", tint=(0.85, 0.9, 1.0))
    B("BenchTop", (0, 0.9, 4.5), (8, 1.0, 5.5), look="metal", tint=(0.55, 0.62, 0.7), shadow=False)
    # Goal tank in the atrium: pedestal + glass walls + lid (gate)
    B("Pedestal", (10, 0, 3.5), (13, 3.8, 6.5), look="fill", tint=(0.9, 0.95, 1.0))
    B("PedestalRim", (9.8, 3.8, 3.3), (13.2, 4.0, 6.7), look="metal", tint=(0.45, 0.55, 0.65))
    B("TankW", (9.8, 4, 3.3), (10, 6, 6.7), kind="glass")
    B("TankE", (13, 4, 3.3), (13.2, 6, 6.7), kind="glass")
    B("TankN", (10, 4, 3.3), (13, 6, 3.5), kind="glass")
    B("TankS", (10, 4, 6.5), (13, 6, 6.7), kind="glass")

    Z = sc.zone
    Z("SpikesN", (11.25, 0.4, 1.75), (5.5, 0.8, 3.5), "spikes")
    Z("SpikesS", (11.25, 0.4, 8.25), (5.5, 0.8, 3.5), "spikes")
    Z("SpikesW", (9.25, 0.4, 5), (1.5, 0.8, 3), "spikes")
    Z("SpikesE", (13.5, 0.4, 5), (1, 0.8, 3), "spikes")
    Z("Goal", (11.5, 4.9, 5), (2.6, 1.6, 2.6), "goal")

    sc.node("RoofTurbine", "Area3D", "Interactive",
            {"transform": xform((9.6, 12.9, 6.2)), "channel": '"exit"', "charge_time": "0.3", "radius": "1.35", "pole_length": "0.85"},
            script="turbine")
    sc.node("TankLid", "AnimatableBody3D", "Interactive",
            {"transform": xform((11.5, 7.15, 5)), "channel": '"exit"', "size": v3((3.4, 0.3, 3.4)),
             "open_offset": v3((0, 0, 3.4)), "duration": "1.0"}, script="gate")

    # --- Decor ---------------------------------------------------------------
    D = decor(sc)
    S = prop(sc)
    S("CabinetW", (0, 0, 0.4), (0.8, 2.6, 3.6), look="dark")
    S("CabinetW2", (0, 0, 6.2), (0.8, 2.6, 9.6), look="dark")
    sc.block("SpecimenTank", (1.3, 0.2, 0.6), (2.7, 2.0, 2.0), kind="glass", parent="Decor")
    D("SpecimenFluid", (1.4, 0.2, 0.7), (2.6, 1.35, 1.9), look="glow", tint=(0.25, 0.95, 0.85))
    S("SpecimenBase", (1.2, 0, 0.5), (2.8, 0.2, 2.1), look="metal", tint=(0.35, 0.42, 0.5))
    S("SpecimenCap", (1.25, 2.0, 0.55), (2.75, 2.12, 2.05), look="metal", tint=(0.35, 0.42, 0.5))
    sc.block("SpecimenTank2", (3.2, 0.2, 0.6), (4.4, 1.6, 1.8), kind="glass", parent="Decor")
    D("SpecimenFluid2", (3.3, 0.2, 0.7), (4.3, 0.9, 1.7), look="glow", tint=(0.5, 0.75, 1.0))
    S("SpecimenBase2", (3.1, 0, 0.5), (4.5, 0.2, 1.9), look="metal", tint=(0.35, 0.42, 0.5))
    S("SpecimenCap2", (3.15, 1.6, 0.55), (4.45, 1.72, 1.85), look="metal", tint=(0.35, 0.42, 0.5))
    S("Monitor", (2.0, 1.12, 4.75), (3.0, 1.72, 4.87), look="glow", tint=(0.35, 0.85, 1.0))
    S("MonitorStand", (2.4, 1.0, 4.74), (2.6, 1.12, 4.9), look="metal", tint=(0.3, 0.35, 0.4))
    flask(sc, "Flask1", (4.45, 1.0, 4.85), (4.7, 1.36, 5.1), (0.4, 1.0, 0.5))
    flask(sc, "Flask2", (4.9, 1.0, 4.75), (5.1, 1.26, 4.95), (1.0, 0.5, 0.9), 0.5)
    flask(sc, "Flask3", (7.0, 1.0, 4.85), (7.25, 1.46, 5.1), (0.4, 0.8, 1.0), 0.7)
    D("WarnStripe", (4.9, 0.0, 0.9), (7.1, 0.02, 3.1), look="glow", tint=(0.9, 0.7, 0.15))
    S("ConsoleE", (7.2, 0, 6.5), (8.0, 1.1, 9.5), look="dark")
    D("ConsoleScreen", (7.15, 0.75, 6.8), (7.2, 1.05, 9.2), look="glow", tint=(0.3, 0.9, 0.7))
    S("CrateM1", (6.6, 4, 7.6), (7.9, 5.2, 9.9), look="dark")
    S("CrateM2", (6.9, 5.2, 8.0), (7.8, 6.0, 9.4), look="dark")
    S("CableTray", (0, 7.4, 0.2), (0.4, 7.6, 9.8), look="metal", tint=(0.5, 0.45, 0.2), shadow=False)
    S("CatwalkLedge", (8.5, 8.35, 0), (14, 8.55, 0.4), look="metal", tint=(0.5, 0.58, 0.66), shadow=False)
    S("TopConsole", (0.2, 8.5, 0.2), (2.5, 9.6, 1.4), look="dark")
    D("TopScreen", (0.4, 9.1, 1.4), (2.3, 9.5, 1.45), look="glow", tint=(1.0, 0.45, 0.3))
    D("TankSign", (10.6, 5.3, 3.24), (12.4, 5.8, 3.29), look="glow", tint=(0.4, 1.0, 0.6))

    sc.pipe("PipeA1", (4.0, 3.15, 9.6), 7.6, "x", 0.15)
    sc.pipe("PipeA2", (4.0, 3.2, 0.35), 7.6, "x", 0.12, color=(0.75, 0.45, 0.2))
    sc.pipe("PipeUp", (13.6, 6.5, 9.6), 13, "y", 0.2)
    sc.pipe("PipeTop", (7, 12.6, 9.55), 14, "x", 0.22)
    sc.pipe("PipeMid", (4.2, 7.7, 0.4), 8, "x", 0.12, color=(0.3, 0.7, 0.6))
    sc.jet("GrateVent", (6, 0.05, 2), height=3.4, period=2.6, burst=1.0)
    sc.jet("TankVent", (13.6, 0.9, 9.3), height=1.6, period=4.0, burst=0.8, phase=1.5)

    L = sc.lamp
    L("LampA1", (2.5, 3.35, 2.6), (0.75, 0.9, 1.0), 1.4, 7.0, fitting=1, tube=2.0)
    L("LampA2", (4.5, 3.35, 7.6), (0.75, 0.9, 1.0), 1.4, 7.0, fitting=1, tube=2.0)
    L("LampMid", (4.5, 7.85, 4.5), (0.6, 1.0, 0.85), 1.3, 7.5, fitting=1, tube=2.5)
    L("LampTop", (4, 12.75, 5), (1.0, 0.85, 0.6), 1.6, 9.0, fitting=1, tube=3.0)
    L("LampAtrium", (12.5, 9.0, 2.0), (0.6, 0.8, 1.0), 1.4, 9.0)
    L("LampTank", (11.5, 2.5, 8.5), (1.0, 0.35, 0.25), 1.0, 5.0, fitting=2, flicker=0.25)

    H = sc.hint
    H("Hint0", (2.4, 2.4, 6.2), "Click: mouse look   \u2190 \u2192: turn")
    H("Hint1", (3.0, 1.9, 4.9), "SPACE: hop the bench")
    H("Hint2", (6.0, 2.5, 3.6), "Heat up (E): STEAM rises")
    H("Hint3", (3.0, 6.8, 6.5), "Gas slips through grates too")
    H("Hint4", (11.0, 10.4, 5.0), "Steam spins turbines. Cool (Q) to land")

    player_rig(sc, (1.8, 0.4, 7.4), 1, {"yaw_deg": "8.0"})
    return sc


# =============================================================================
# Chapter 6 - Crosswind (sewer, 2.5D side view)
# =============================================================================
def level_06():
    sc = Scene()
    level_header(sc, "6 - Crosswind", "sewer", 2, {"kill_y": "-4.0"}, sun_rot=(-0.7, 0.35, 0))
    B = sc.block
    zf, zb = 1.6, -2.0   # corridor front/back
    B("Floor", (-1, -1, -2.5), (37, 0, 2.2))
    B("WallW", (-1, 0, -2.5), (0, 12, 2.2))
    B("WallE", (36, 0, -2.5), (37, 12, 2.2))
    B("Ceiling", (-1, 11, -2.5), (37, 12, 2.2))
    B("BackWall", (0, 0, -2.5), (36, 11, -2.0), look="dark")
    B("StartLedge", (0, 0, zb), (6, 2, zf))
    B("Ledge2", (8, 0, zb), (16, 2, zf))
    B("Grate", (11, 2, zb), (11.6, 4.2, zf), kind="grate")
    B("HangWall", (11, 4.2, zb), (11.6, 11, zf))
    B("Baffle", (22, 7.4, zb), (23, 11, zf))
    B("GoalLedge", (30, 0, zb), (36, 4, zf))
    B("PitWallL", (16, 0, zb), (16.3, 2, zf), look="dark")

    Z = sc.zone
    Z("SpikeGap", (7, 0.4, -0.2), (2, 0.8, 3.6), "spikes")
    Z("PitSpikes", (23.15, 0.4, -0.2), (13.7, 0.8, 3.6), "spikes")
    Z("CeilingSpikes", (24.5, 10.5, -0.2), (11, 1.0, 3.6), "spikes", rot=(0, 0, PI))
    Z("ColdDrip", (9.5, 3.1, -0.2), (1.4, 2.2, 3.0), "freeze")
    Z("SideFan", (21.5, 4.8, -0.2), (3.6, 17, 3.4), "fan", rot=(0, 0, -PI / 2), extra={"push_strength": "56.0"})
    Z("Goal", (34.4, 5.1, 0), (2, 2, 2), "goal")

    D = decor(sc)
    S = prop(sc)
    # Liquid layers: the blob sinks into them on purpose (the pit spikes do the killing).
    D("Sludge", (16.3, 0, zb), (30, 0.12, zf), look="glow", tint=(0.25, 0.55, 0.2), passable=True)
    D("SludgeGap", (6, 0, zb), (8, 0.12, zf), look="glow", tint=(0.25, 0.55, 0.2), passable=True)
    for i, x in enumerate((6, 16.3, 24, 30)):
        S("Arch%d" % i, (x - 0.35, 0, -2.0), (x + 0.35, 9.6, -1.6), look="wall")
    S("ArchBeam", (0, 9.6, -2.0), (36, 10.0, -1.6), look="dark")
    S("FanMount", (12.6, 2.6, -2.0), (13.2, 7.0, -1.6), look="dark")
    D("Walkway", (30, 4, -2.0), (36, 4.08, 1.6), look="metal", tint=(0.4, 0.45, 0.4), shadow=False)
    S("OutfallL", (25.5, 2.4, -2.0), (27.0, 3.6, -1.6), look="dark")
    S("OutfallR", (3.0, 3.2, -2.0), (4.4, 4.4, -1.6), look="dark")
    S("FrontPipeBase", (0, 0, 2.2), (36, 0.3, 2.6), look="dark")
    sc.pipe("PipeBackHi", (18, 8.6, -1.75), 36, "x", 0.25, flange=2.0)
    sc.pipe("PipeBackLo", (18, 1.0, -1.8), 36, "x", 0.16, color=(0.55, 0.42, 0.25), flange=2.0)
    sc.pipe("PipeV1", (9.0, 6.5, -1.75), 9, "y", 0.18)
    sc.pipe("PipeV2", (28.0, 6.0, -1.75), 10, "y", 0.2)
    sc.pipe("PipeDrip", (9.5, 4.8, -0.2), 3.6, "z", 0.15)
    sc.pipe("FrontPipe", (18, 0.25, 2.8), 36, "x", 0.25, flange=3.0)
    sc.jet("OutfallSteam", (26.25, 3.0, -1.4), height=1.5, period=3.5, burst=1.2)
    sc.jet("OutfallSteam2", (3.7, 3.8, -1.4), height=1.5, period=4.2, burst=1.0, phase=2.0)

    L = sc.lamp
    L("Lamp1", (3, 6.5, -1.5), (1.0, 0.82, 0.5), 1.5, 8, flicker=0.15)
    L("Lamp2", (13.8, 8.2, -1.5), (0.6, 1.0, 0.75), 1.4, 9)
    L("Lamp3", (23.5, 7.0, -1.5), (0.6, 1.0, 0.75), 1.3, 9)
    L("Lamp4", (33, 8.5, -1.5), (1.0, 0.82, 0.5), 1.5, 8)
    L("SludgeGlow", (23, 1.2, 0.5), (0.4, 0.9, 0.3), 1.0, 7, fitting=2)

    H = sc.hint
    H("Hint1", (3.2, 4.2, 0), "SPACE / W: hop the gap")
    H("Hint2", (9.0, 5.6, 0), "Frozen solid? Melt (E) to slip through")
    H("Hint3", (15.5, 8.3, 0), "Side fans blow STEAM sideways")
    H("Hint4", (25.5, 8.6, 0), "Don't drift into the ceiling spikes!")

    player_rig(sc, (1.5, 2.4, 0), 1, {"side_distance": "12.5"})
    return sc


# =============================================================================
# Chapter 8 - Chain Reaction (boiler, first person)
# =============================================================================
def level_08():
    sc = Scene()
    level_header(sc, "8 - Chain Reaction", "boiler", 1, {"kill_y": "-8.0"}, sun_rot=(-1.2, 0.9, 0))
    B = sc.block
    # Boiler room (x0..12, z0..9, y0..4.5)
    B("FloorMain", (-1, -1, -1), (11.6, 0, 10))
    B("FloorE", (11.6, -1, 3.4), (13, 0, 10))
    B("WallW", (-1, 0, -1), (0, 12.5, 10))
    B("WallN", (0, 0, -1), (11.6, 12.5, 0))
    B("WallS", (0, 0, 9), (12.4, 5, 10))
    B("RoomWallE", (11.6, 0, 3.4), (12.4, 5, 9))
    B("RoomCeil", (3.4, 4.5, 0), (11.6, 5, 9))
    B("RoomCeilW", (0, 4.5, 3.4), (3.4, 5, 9))
    # Shaft (x0..3, z0..3) up to the duct
    B("ShaftE", (3, 2.2, 0), (3.4, 9.5, 3))
    B("ShaftS", (0, 0, 3), (3.4, 12.5, 3.4))
    B("ShaftCeil", (0, 12, 0), (3.4, 12.5, 3))
    # Duct (x3.4..12, z0..3, y9.5..12)
    B("DuctFloor", (3.4, 9, 0), (12, 9.5, 3))
    B("DuctCeil", (3.4, 12, 0), (11.6, 12.5, 3))
    B("DuctS", (3.4, 5, 3), (11.6, 12.5, 3.4))
    # Well (x12..15, z0..3) down to the basement
    B("WellW", (11.6, -5, 0), (12, 9, 3.4))
    B("WellE", (15, -5, 0), (15.4, 12, 3.4))
    B("WellN", (11.6, -5, -0.4), (15.4, 12, 0))
    B("WellS", (12, -5, 3), (15, 12, 3.4))
    B("WellCeil", (11.6, 12, -0.4), (15.4, 12.5, 3.4))
    B("WellFloor", (12, -5.5, 0), (15, -4.5, 3))
    B("Cracked1", (12, 4, 0), (15, 4.5, 3), kind="breakable")
    B("Cracked2", (12, -0.5, 0), (15, 0, 3), kind="breakable")
    # Boilers (solid)
    B("Boiler1", (7, 0, 6.8), (10.4, 3.4, 8.9))
    B("Boiler2", (0.2, 0, 5.4), (2.4, 3.0, 8.6))
    B("Crate1", (10.2, 0, 0.3), (11.5, 1.2, 1.6), look="dark")
    B("Crate2", (10.4, 1.2, 0.5), (11.3, 2.0, 1.4), look="dark")

    Z = sc.zone
    Z("ShaftVent", (1.5, 0.9, 1.5), (2.6, 1.8, 2.6), "heat")
    Z("SpikeStrip", (5.6, 0.4, 4.5), (1.2, 0.8, 9.0), "spikes")
    Z("Goal", (13.5, -3.5, 1.5), (2.4, 2, 2.4), "goal")

    sc.node("ShaftTurbine", "Area3D", "Interactive",
            {"transform": xform((1.5, 8.4, 1.5)), "channel": '"attic"', "charge_time": "0.3", "radius": "1.35"},
            script="turbine")
    sc.node("AtticShutter", "AnimatableBody3D", "Interactive",
            {"transform": xform((6.2, 10.75, 1.5)), "channel": '"attic"', "size": v3((0.3, 2.5, 3.0)),
             "open_offset": v3((0, -2.6, 0)), "duration": "0.9"}, script="gate")

    D = decor(sc)
    D("Firebox", (7.9, 0.4, 6.74), (9.4, 1.3, 6.8), look="glow", tint=(1.0, 0.45, 0.12))
    D("Firebox2", (2.4, 0.4, 6.3), (2.45, 1.2, 7.7), look="glow", tint=(1.0, 0.45, 0.12))
    D("Gauge1", (7.3, 2.4, 6.74), (7.7, 2.8, 6.8), look="glow", tint=(1.0, 0.85, 0.5))
    D("Gauge2", (9.6, 2.4, 6.74), (10.0, 2.8, 6.8), look="glow", tint=(0.6, 1.0, 0.6))
    D("BoilerBand1", (6.95, 1.6, 6.75), (10.45, 1.75, 8.95), look="metal", tint=(0.75, 0.55, 0.3), shadow=False)
    D("BoilerBand2", (0.15, 1.6, 5.35), (2.45, 1.75, 8.65), look="metal", tint=(0.75, 0.55, 0.3), shadow=False)
    S = prop(sc)
    S("ShaftLip", (2.95, 2.1, 0), (3.45, 2.3, 3.0), look="metal", tint=(0.8, 0.5, 0.25))
    D("SpikeWarn", (4.8, 0.0, 0.0), (5.0, 0.02, 9.0), look="glow", tint=(1.0, 0.75, 0.1))
    D("SpikeWarn2", (6.2, 0.0, 0.0), (6.4, 0.02, 9.0), look="glow", tint=(1.0, 0.75, 0.1))
    S("DuctRib1", (5.0, 9.5, 0.0), (5.2, 12.0, 0.15), look="metal", tint=(0.6, 0.45, 0.3))
    S("DuctRib2", (8.5, 9.5, 0.0), (8.7, 12.0, 0.15), look="metal", tint=(0.6, 0.45, 0.3))
    S("DuctRib3", (8.5, 9.5, 2.85), (8.7, 12.0, 3.0), look="metal", tint=(0.6, 0.45, 0.3))
    D("WellSign", (12.9, 9.6, 2.95), (14.1, 10.0, 3.0), look="glow", tint=(1.0, 0.3, 0.15))
    D("BasementGlow", (12.2, -4.5, 0.2), (14.8, -4.45, 2.8), look="glow", tint=(0.3, 0.9, 0.5))

    sc.pipe("PipeB1", (8.7, 4.0, 7.85), 1.2, "y", 0.35, color=(0.55, 0.4, 0.3))
    sc.pipe("PipeRoof", (7.5, 4.15, 0.4), 8, "x", 0.2)
    sc.pipe("PipeRoof2", (7.5, 4.15, 8.6), 8, "x", 0.16, color=(0.7, 0.5, 0.25))
    sc.pipe("PipeWallW", (0.35, 2.0, 4.5), 1.5, "z", 0.18)
    sc.pipe("PipeShaft", (0.3, 6.5, 0.3), 11, "y", 0.14, color=(0.7, 0.5, 0.25))
    sc.pipe("PipeDuct", (7.5, 11.75, 0.3), 8, "x", 0.12)
    sc.pipe("PipeWell", (14.7, 3.5, 0.3), 15, "y", 0.14, color=(0.7, 0.5, 0.25))
    sc.jet("ValveSteam", (10.4, 3.0, 7.85), height=1.4, period=3.0, burst=0.8, rot=(0, 0, -PI / 2))
    sc.jet("BoilerSteam", (1.3, 3.0, 7.0), height=1.8, period=4.0, burst=1.2, phase=1.0)

    L = sc.lamp
    L("FireGlow", (8.6, 1.0, 6.2), (1.0, 0.5, 0.18), 2.0, 6.0, fitting=2, flicker=0.3)
    L("RoomLamp", (8.0, 4.25, 3.5), (1.0, 0.78, 0.5), 1.4, 9.0, fitting=1, tube=2.0)
    L("DuctLamp", (8.0, 11.85, 1.5), (1.0, 0.7, 0.45), 1.2, 6.0, fitting=0)
    L("WellLamp", (13.5, 11.7, 1.5), (1.0, 0.55, 0.3), 1.4, 8.0, fitting=0, flicker=0.2)
    L("WellMid", (13.5, 2.4, 0.3), (1.0, 0.55, 0.3), 1.0, 5.0, fitting=0)

    H = sc.hint
    H("Hint1", (5.6, 1.7, 4.5), "Spikes! Hop them (SPACE) or go ICE (Q)")
    H("Hint2", (4.1, 2.9, 1.5), "Hot vent: you'll turn to STEAM")
    H("Hint3", (10.4, 11.15, 1.5), "Over the well: freeze and fall")
    H("Hint4", (13.5, 7.5, 1.5), "Break them all!")

    player_rig(sc, (9.3, 0.4, 4.6), 1, {"yaw_deg": "90.0"})
    return sc


if __name__ == "__main__":
    from gen3d_phase2 import level_05, level_10, level_12
    only = sys.argv[1:] or ["03", "05", "06", "08", "10", "12"]
    for key, fn in (("03", level_03), ("05", level_05), ("06", level_06), ("08", level_08),
                    ("10", level_10), ("12", level_12)):
        if key not in only:
            continue
        name = "level_%s_3d.tscn" % key
        with open(os.path.join(ROOT, name), "w", newline="\n", encoding="utf-8") as fh:
            fh.write(fn().text())
        print("wrote", name)
