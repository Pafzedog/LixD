    module game.core.draw;

import std.conv; // replay sign
import std.math; // sin, for replay sign
import std.range : retro;
import std.string; // format

import basics.alleg5;
import basics.globals; // replay sign
import game.core.game;
import game.tribe;
import graphic.color;
import graphic.cutbit; // replay sign
import graphic.gadget;
import graphic.internal;
import graphic.map;
import graphic.torbit;
import hardware.display;
import hardware.tharsis;

package void
implGameDraw(Game game) { with (game)
{
    auto zo = Zone(profiler, "game entire implGameDraw()");
    nurse.applyChangesToLand();

    with (Zone(profiler, "game entire drawing to map"))
    {
        // speeding up drawing by setting the drawing target now.
        // This RAII struct is used in each innermost loop, too, but it does
        // nothing except comparing two pointers there if we've set stuff here.
        DrawingTarget drata = DrawingTarget(map.albit);

        with (level)
            map.clearScreenRect(color.makecol(bgRed, bgGreen, bgBlue));
        game.drawGadgets();
        game.drawLand();
        effect.draw(map);
        effect.calc(); // --timeToLive, moves. No physics, so OK to calc here.
        game.drawAllLixes();
        pan.stats.updatesSinceZero(nurse.updatesSinceZero);
        pan.stats.showTribe(tribeLocal);
    }
    DrawingTarget drata = DrawingTarget(al_get_backbuffer(display));
    with (Zone(profiler, "game draws map to screen"))
        map.drawCamera();
    game.drawReplaySign();
}}
// end with(game), end implGameDraw()

private:

void drawGadgets(Game game)
{
    auto zone  = Zone(profiler, "game draws gadgets");
    auto state = game.nurse.constStateForDrawingOnly;
    state.foreachConstGadget((const(Gadget) g) {
        with (Zone(profiler, "game draws one gadget"))
            g.draw(game.map, state);
    });
}

void drawLand(Game game)
{
    auto zone = Zone(profiler, "game draws land to map");
    game.map.loadCameraRect(game.nurse.land);
}

void drawAllLixes(Game game)
{
    auto zone = Zone(profiler, "game draws lixes");
    void drawTribe(in Tribe tr)
    {
        foreach (lix; tr.lixvec.retro)
            if (! lix.marked)
                lix.draw(game.map);
        foreach (lix; tr.lixvec.retro)
            if (lix.marked)
                lix.draw(game.map);
    }
    with (game) {
        foreach (otherTribe; nurse.constStateForDrawingOnly.tribes)
            if (otherTribe !is game.tribeLocal)
                drawTribe(otherTribe);
        drawTribe(nurse.constStateForDrawingOnly.tribes[_indexTribeLocal]);
    }
}

void drawReplaySign(Game game)
{
    if (! game.replaying)
        return;
    const(Cutbit) rep = getInternal(fileImageGameReplay);
    rep.drawToCurrentTarget(Point(0,
        (rep.yl/5 * (1 + sin(timerTicks * 0.08f))).to!int));
}
