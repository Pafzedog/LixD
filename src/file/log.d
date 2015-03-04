module file.log;

import std.stdio;
import std.string;
public import std.string : format;

import basics.alleg5;
import basics.globals;
import file.date;

class Log {

public:

    static void initialize();
    static void deinitialize();

    static void log (int);
    static void log (string);
    static void log (string, int);
    static void log (string  string);

private:

    static Log singl;

    std.stdio.File file;

    this();

    bool something_was_logged_already_this_session;
    static void   log_header_if_necessary();
    static string format_al_ticks();



public:

static void initialize()
{
    if (! singl) singl = new Log;
}



static void deinitialize()
{
    if (singl) {
        clear(singl);
        singl = null;
    }
}



private this()
{
    file = std.stdio.File(gloB_file_log.get_rootful(), "a");
    something_was_logged_already_this_session = false;
}



private ~this()
{
    file.close();
}



private static void log_header_if_necessary()
{
    assert (singl);
    if (singl.something_was_logged_already_this_session) return;
    else {
        singl.something_was_logged_already_this_session = true;

        // a free line and then the current datetime in its own line
        singl.file.writefln("");
        singl.file.writefln((new Date()).toString);
    }
}



private static string format_al_ticks()
{
    return format("%9.2f", al_get_timer_count(basics.alleg5.timer)
                                            / basics.alleg5.timer_per_sec);
}



static void log(int i)
{
    log_header_if_necessary();
    singl.file.writefln("%s %d", format_al_ticks(), i);
}



static void log(string s)
{
    log_header_if_necessary();
    singl.file.writefln("%s %s", format_al_ticks(), s);
}



static void log(string s, int i)
{
    log_header_if_necessary();
    singl.file.writefln("%s %s %d", format_al_ticks(), s, i);
}



static void log(string s1, string s2)
{
    log_header_if_necessary();
    singl.file.writefln("%s %s %s", format_al_ticks(), s1, s2);
}

}
// end class
