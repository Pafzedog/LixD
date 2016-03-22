module graphic.cutbit;

import std.algorithm; // max(-x, 0) in drawDirectlyToScreen()
import std.string; // format

public import basics.rect;

import basics.alleg5;
import basics.help; // positiveMod
import basics.matrix; // which frames exist?
import graphic.color;
import graphic.torbit;
import graphic.textout; // write error message instead of drawing bitmap
import file.filename;
import file.language;
import file.log; // log bad filename when trying to load a bitmap
import hardware.display; // drawDirectlyToScreen()

class Cutbit {
private:
    Albit bitmap;
    int _xl;
    int _yl;
    int _xfs; // number of x-frames existing: xf in the interval [0, _xfs[
    int _yfs; // number of y-frames existing
    Matrix!bool _existingFrames;

public:
    enum Mode {
        NORMAL,
        NOOW, // no-overwrite, draw only the pixels falling on transparent bg
        DARK, // instead of drawing a pixel, erase a pixel from the bg
        DARK_EDITOR, // like DARK, but draw a dark color, not transparent
    }

/*  this() { }
 *  this(Cutbit);
 *  this(Albit,    bool cut = true); // takes ownership of bitmap!
 *  this(Filename, bool cut = true);
 *  this(Albit[]);
 *
 *  bool opEquals(const Cutbit) const;
 */
    @property bool  valid() const { return bitmap != null; }
    @property Albit albit() const { return cast (Albit) bitmap; }

    // get size of a single frame, not necessarily size of entire bitmap
    @property int   xl()  const { return _xl;  }
    @property int   yl()  const { return _yl;  }
    @property Point len() const { return Point(_xl, _yl); }
    @property int   xfs() const { return _xfs; }
    @property int   yfs() const { return _yfs; }

    // these two are slow, consider frameExists() instead
    // or lock the Cutbit's underlying Allegro bitmap yourself
    AlCol get_pixel(int px, int py)                 const;
    AlCol get_pixel(int fx, int fy, int px, int py) const;

/*  bool frameExists(in int fx, in int fy) const;
 *
 *      Checks whether the given frame contains interesting image data,
 *      instead of being marked as nonexistant by being filled with the
 *      already-detected frame/grid color.
 *
 *      This is very fast, it uses the cached data in RAM. It's much better
 *      to consult this instead of querying for pixels later inside frames.
 *
 *  void draw(torbit, x, y, xf, yf, mirr, double rot, double scal) const;
 *  void draw(torbit, x, y,         mirr, int    rot, Mode   mode) const;
 *
 *      The first is intended for free-form drawing without effect on land.
 *      Interactive objects and the flying pickaxe are drawn with this.
 *
 *      The second is intended to draw terrain and steel. These can only
 *      be rotated by quarter turns, and have only one frame per piece.
 *      However, they can be drawn with one of the drawing modes, like
 *      no-overwrite or dark.
 *
 *      (rot) (either int or double) means how many quarter turns to be made.
 *      I believe they're measured counter-clockwise.
 *
 *      (double scal) can be set to 0 or 1 when one doesn't wish to rescale.
 *
 *  void drawDirectlyToScreen(x, y, xf, yf)
 *
 *      This should only be used by the mouse cursor, which draws even on top
 *      of the gui torbit. Rotation, mirroring, and scaling is not offered.
 */

this(Cutbit cb)
{
    if (! cb) return;
    _xl = cb._xl;
    _yl = cb._yl;
    _xfs = cb._xfs;
    _yfs = cb._yfs;
    _existingFrames = new Matrix!bool (cb._existingFrames);

    if (cb.bitmap) {
        bitmap = albitCreate(al_get_bitmap_width (cb.bitmap),
                             al_get_bitmap_height(cb.bitmap));
        auto drata = DrawingTarget(bitmap);
        al_draw_bitmap(cast (Albit) cb.bitmap, 0, 0, 0);
        assert(bitmap);
    }

}

// Takes ownership of the argument bitmap!
this(Albit bit, const bool cut = true)
{
    bitmap = bit;
    if (! bitmap) return;

    if (cut) cutBitmap();
    else {
        _xl = al_get_bitmap_width (bitmap);
        _yl = al_get_bitmap_height(bitmap);
        _xfs = 1;
        _yfs = 1;

        _existingFrames = new Matrix!bool(1, 1);
        _existingFrames.set(0, 0, true);
    }
}

this(const Filename fn, const bool cut = true)
{
    // Try loading the file. If not found, don't crash, but make a log entry.
    bitmap = al_load_bitmap(fn.rootfulZ);
    if (bitmap)
        al_convert_mask_to_alpha(bitmap, color.pink);
    this(bitmap, cut);
}

~this() { dispose(); }

void dispose()
{
    if (bitmap) {
        al_destroy_bitmap(bitmap);
        bitmap = null;
    }
}

bool opEquals(const Cutbit rhs) const
{
    return bitmap == rhs.bitmap;
}




AlCol get_pixel(int px, int py) const
{
    return get_pixel(0, 0, px, py);
}



AlCol get_pixel(int fx, int fy,
                int px, int py) const
{
    // frame doesn't exist, or pixel doesn't exist in the frame
    if  (fx < 0 || fy < 0 || fx >= _xfs || fy >= _yfs
     ||  px < 0 || py < 0 || px >= _xl  || py >= _yl) {
        return color.bad;
    }
    // otherwise, return the found color
    else if (_xfs == 1 && _yfs == 1)
         return al_get_pixel(cast (Albit) bitmap, px, py);
    else return al_get_pixel(cast (Albit) bitmap, fx * (_xl+1) + 1 + px,
                                                  fy * (_yl+1) + 1 + py);
}



bool frameExists(in int fx, in int fy) const
{
    if (fx < 0 || fx >= _xfs
     || fy < 0 || fy >= _yfs) return false;
    else return _existingFrames.get(fx, fy);
}

void draw(
    Torbit       targetTorbit,
    const Point  targetCorner,
    const int    xf = 0,
    const int    yf = 0,
    const bool   mirr = false,
    const double rot  = 0,
    const double scal = 0) const
{
    assert (targetTorbit, "trying to draw onto null torbit");
    Albit target = targetTorbit.albit;

    if (bitmap && xf >= 0 && yf >= 0 && xf < _xfs && yf < _yfs) {
        Albit sprite = create_sub_bitmap_for_frame(xf, yf);
        scope (exit) al_destroy_bitmap(sprite);
        targetTorbit.drawFrom(sprite, targetCorner, mirr, rot, scal);
    }
    // no frame inside the cutbit has been specified, or the cutbit
    // has a null bitmap
    else {
        drawMissingFrameError(targetTorbit, targetCorner, xf, yf);
    }
}

void draw(
    Torbit   targetTorbit,
    in Point targetCorner,
    in bool  mirr,
    int      rot,
    in Mode  mode) const
{
    assert (targetTorbit, "trying to draw onto null torbit");

    if (! bitmap) {
        drawMissingFrameError(targetTorbit, targetCorner, 0, 0);
        return;
    }
    // only one frame allowed, so we don't have to make sub-bitmaps
    assert (_xfs == 1);
    assert (_yfs == 1);

    rot = basics.help.positiveMod(rot, 4);
    assert (rot >= 0 || rot < 4);

    final switch (mode) {
    case Mode.NORMAL:
        // this is very much like the other draw function
        targetTorbit.drawFrom(bitmap, targetCorner, mirr, rot * 1.0f);
        break;
    case Mode.DARK:
    case Mode.DARK_EDITOR:
        with (BlenderMinus)
            targetTorbit.drawFrom(bitmap, targetCorner, mirr, rot);
        break;
    case Mode.NOOW:
        // DTODO: implement NOOW drawing
        goto case Mode.NORMAL;
    }
    // we don't have to draw the missing-frame error here; there could have
    // only been the missing-image error, and we've checked for that already.
}
// end function draw with mode

void
drawToCurrentTarget(in Point targetCorner, in int xf = 0, in int yf = 0) const
{
    assert (display);
    if (xf < 0 || xf >= _xfs
     || yf < 0 || yf >= _yfs) return;
    // usually, select only the correct frame. If we'd draw off the screen
    // to the left or top, instead do extra cutting by passing > 0 to the
    // latter two args.
    Albit sprite = create_sub_bitmap_for_frame(xf, yf,
        max(-targetCorner.x, 0), max(-targetCorner.y, 0));
    scope (exit)
        al_destroy_bitmap(sprite);
    al_draw_bitmap(sprite, max(0, targetCorner.x), max(0, targetCorner.y), 0);
}

private:
    void drawMissingFrameError(
        Torbit torbit, in Point targetCorner, in int fx, in int fy) const
    {
        string str = "File N/A";
        AlCol  col = color.cbBadBitmap;
        if (bitmap) {
            str = format("(%d,%d)", fx, fy);
            col = color.cbBadFrame;
        }
        auto drata = DrawingTarget(torbit.albit);
        drawText(djvuS, str, targetCorner.x, targetCorner.y, col);
    }

    // this is used by the first draw(), and by drawDirectlyToScreen()
    Albit create_sub_bitmap_for_frame(
        in int xf, in int yf,
        in int xec = 0, // extra cutting from top or left
        in int yec = 0) const
    in {
        assert (xf >= 0 && xf < _xfs);
        assert (yf >= 0 && yf < _yfs);
        assert (xec >= 0 && xec < _xl); // _xl, _yl are either all the bitmap, or
        assert (yec >= 0 && yec < _xl); // the size of a single frame without grid
    }
    body {
        // Create a sub-bitmap based on the wanted frames. If (Cutbit this)
        // doesn't have frames, don't compute +1 for the outermost frame.
        if (_xfs == 1 && _yfs == 1)
            return al_create_sub_bitmap(cast (Albit) bitmap,
             xec, yec, _xl - xec, _yl - yec);
        else
            return al_create_sub_bitmap(cast (Albit) bitmap,
             1 + xf * (_xl+1) + xec,
             1 + yf * (_yl+1) + yec,
             _xl - xec, _yl - yec);
    }

    void cutBitmap()
    {
        auto lock = LockReadOnly(bitmap);
        immutable int xMax = al_get_bitmap_width (bitmap);
        immutable int yMax = al_get_bitmap_height(bitmap);
        // Called when the constructor was invoked with bool cut == true.
        // To cut a bitmap into frames, check the top left 2x2 block. The three
        // pixels of it touching the edge shall be of one color, and the inner
        // pixel must be of a different color, to count as a frame grid.
        AlCol c = al_get_pixel(bitmap, 0, 0);
        if (xMax > 1 && yMax > 1
         && al_get_pixel(bitmap, 0, 1) == c
         && al_get_pixel(bitmap, 1, 0) == c
         && al_get_pixel(bitmap, 1, 1) != c) {
            // find the end of the first frame in each direction
            for (_xl = 2; _xl < xMax; ++_xl) {
                if (al_get_pixel(bitmap, _xl, 1) == c) {
                    --_xl;
                    break;
                }
            }
            for (_yl = 2; _yl < yMax; ++_yl) {
                if (al_get_pixel(bitmap, 1, _yl) == c) {
                    --_yl;
                    break;
                }
            }

            // don't cut the bitmap if at most 1-by-1 frame is possible
            if (_xl * 2 > xMax && _yl * 2 > yMax) {
                _xl = xMax;
                _yl = yMax;
                _xfs = 1;
                _yfs = 1;
            }
            // ...otherwise compute the number of frames in each direction
            else {
                for (_xfs = 0; (_xfs+1)*(_xl+1) < xMax; ++_xfs) {}
                for (_yfs = 0; (_yfs+1)*(_yl+1) < yMax; ++_yfs) {}
            }
        }
        // no frame apparent in the top left 2x2 block of pixels
        else {
            _xl = xMax;
            _yl = yMax;
            _xfs = 1;
            _yfs = 1;
        }
        // done cutting, now generate matrix. The bitmap is still locked.
        _existingFrames = new Matrix!bool(_xfs, _yfs);
        if (_xfs == 1 && _yfs == 1) {
            _existingFrames.set(0, 0, true);
        }
        else {
            for (int yf = 0; yf < _yfs; ++yf)
             for (int xf = 0; xf < _xfs; ++xf) {
                immutable bool has_frame_color = (get_pixel(xf, yf, 0, 0) == c);
                _existingFrames.set(xf, yf, ! has_frame_color);
            }
        }
        // done making the matrix
    }
    // end void cutBitmap()
}
