// KT-Lucid Light
//
// Script to activate and deactivate normal lights
// Part of the KrakenTech Lucid Lighting System
//
// The Lucid Lighting System consists of three parts
//      Lights - For illumination or just for glowing when on
//      Switches - Either manual or automatic
//      Control Boxes - For tracking everything and tying them together
//
// This is the core script for Lucid Lights.  There might be variants available for
// specialized lighting.
// 
// Licensed with the GPL v3.0 (https://www.gnu.org/licenses/gpl-3.0.html)
// Copylefted Free Software - You may redistribute, but MUST redistribute the matching
// script code with the redistribution.  This is preferably done by leaving the script as
// Modify inside the object, but other options are available, see link above.
// 
// All KrakenTech objects distriubuted with this system are likewise GPL Licensed
// and must be available to modify and redistribute by anyone you distribute to.
// You may limit objects you make as long as this code is still modifyable and
// redistributable according to the terms of the GPL v3.0.


// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * Global Constants
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

integer debugLevel  = 2;                    // Current level of debugging info for owner

string software = "KT-Lucid Light";         // The name of the script code
string version  = "0.01-development";       // The current version of the script code

// ~~ Move to notecard
integer lucidSubChannel     = 0;    // The subchannel this set of Lucid lights uses 0-99
                                    // Subchannels MUST match between all elements of the
                                    // same Lucid Lighting system for it to interoperate!

// Base channels used to calculate the channels to use to communicate with the other objects
// in the Lucid Lighting system.
// 1783 is the year a giant tentacle was found in the belly of a Sperm Whale
integer controlChannelBase  = 1783001100;   // The base channel to talk to the control unit
integer switchChannelBase   = 1783001200;   // The base channel to talk to the switch

integer messageMaxLength    = 200;          // Anything past this length in input will be ignored

string  commandPrefix       = "lucid";      // This must start every command, both control & switch
string  commentPrefix       = "#";          // Starts a comment

string  notecardControl     = "Light Control";  // The notecard name with control settings
string  notecardSettings    = "Light Settings"; // The notecard name with lighting settings


// Indicate current state of various subsystems:
integer OFF     = FALSE;                // Subsystem is off, not yet active
integer ON      = TRUE;                 // Subsystem is on, active and ready
integer INIT    = -1;                   // Subsystem is initializing, getting set up



// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * Global Variables
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

string scriptName;              // The script name, including version info

integer controlChannel;         // The actual control channel to use
integer switchChannel;          // The actual switch channel to use

integer controlHandle   = FALSE;    // The handle to manage communication with the control unit
integer switchHandle    = FALSE;    // The handle to manage communication with switches

integer commandLength;              // The length of commandPrefix
integer commentLength;              // The length of commentPrefix

// State-based indicators:
integer light                       = OFF;      // Is the light on or off?
integer commSubsystem               = OFF;      // Communications system active yet?
integer controlSettingsSubsystem    = OFF;      // Control settings loaded yet?
integer lightingSettingsSubsystem   = OFF;      // Lighting settings loaded yet?

// Settings lists
list notecardLines      = [];       // The list of lines in the notecard being loaded
list controlSettings    = [];       // Strided list of control settings (stride=2)
list lightingSettings   = [];       // Strided list of lighting settings (stride=2)

// Notecard loading additional information
integer notecardLoading     = FALSE;    // Are we currently loading a notecard?
key     notecardHandle      = NULL_KEY; // Handle for the currently loading notecard
string  notecardName        = "";       // Name for the currently loading notecard
integer notecardCurLine     = 0;        // What notecard line is next?
integer notecardNumLines    = 0;        // How many lines are in the notecard?

integer cmdPrefixLength;                // Length of the comamnd prefix



// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * Functions
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


// debug( integer, string )"
// Send owner a debug message if and only if global constant debugLevel is high enough
debug( integer level, string message )
{
    if ( debugLevel >= level ) {
        llOwnerSay( "! " + message );
    }
}


// Output an error message
error( string message )
{
    llOwnerSay( "!!! " + message );
}


// string preprocessString(string):
// Preprocess the string for easier handling.  This function
//      - Removes leading and trailing spaces
//      - Removes comments starting with commentPrefix
//      - Trims the line to no longer than messageMaxLength
//      - Forces characters to lowercase
string preprocessString( string s )
{
    string p = llStringTrim( s, STRING_TRIM );          // Clean up leading & traling spaces
    p = llGetSubString( p, 0, messageMaxLength-1 );     // Trim the string for safety
    p = llToLower( p );                                 // Force everything lowercase

    // Find and remove a comment, if present
    integer i = llSubStringIndex( s, commentPrefix );
    if ( i == 0 ) return "";                            // Whole line is comment
    if ( i > 0 ) {                                      // Part of line is comment
        p = llGetSubString( p, 0, i-1 );                // Grab up to but not including comment
        p = llStringTrim( p, STRING_TRIM_TAIL );        // Trim more if needed
    }

    return p;
}


// initializeCommunication():
// Initialize the communication channels with the control unit and switches
// Initialize communication itself with the control unit
initializeCommunication()
{
    if ( commSubsystem == ON ) {    // Communication system is already initialized, quietly skip it
        return;
    }

    commSubsystem = INIT;   // We are now initializing the communications subsystem

    // Calculate the channels to listen on, to talk to the control unit and switches
    controlChannel  = controlChannelBase + lucidSubChannel;     // Calculate control channel
    switchChannel   = switchChannelBase + lucidSubChannel;      // Calculate switch channel
    debug( 1, "controlChannel: "+(string)controlChannel );
    debug( 1, "switchChannel: "+(string)switchChannel );

    // Initialize both listen channels
    controlHandle   = llListen( controlChannel, "", NULL_KEY, "" );
    switchHandle    = llListen( switchChannel, "", NULL_KEY, "" );

    // ~~ Register with the control unit, need an asynchornous part ~~
    commSubsystem = ON;     // Communications subsystem is now online ~~move to asynchronous part~~
}


// integer isAuthorized( key, string ):
// Determine whether or not the message qualifies as an authorized command to be parsed
// An authorized message must
//      - Be sent by the owner or an object owned by the same owner
//      - Begin with prefixString
integer isAuthorized( key id, string message )
{
    // Only the owner, or objects owned by the owner, are allowed to send commands within Lucid
    if ( llGetOwnerKey(id) != llGetOwner() ) {
        return FALSE;
    }

    // ~~ Check if it's on the list of known devices sent by control unit ~~

    // Authorized messages must start with the prefixString
    string p = llGetSubString( message, 0, commandLength-1 );
    if ( p != commandPrefix ) {
        return FALSE;
    }

    return TRUE;
}


// list handleMessage( key, string ):
// Do all the preliminary steps to handle an incoming message on one of the listen channels
// This includes:
//      - Trimming leading & trailing spaces
//      - Capping the message at a length of messageMaxLength, for safer parsing
//      - Forcing the message to lowercase, for easier parsing
//      - Verifying the message is an authorized one
//      - Splitting it on "|" to form a parsed list
list handleMessage( key id, string message )
{
    string m;                   // Store the processed message
    list cmd = [];              // Store the parsed command

    // Preprocess the message for easier handling
    m = llStringTrim( message, STRING_TRIM );           // Clean up leading & traling spaces
    m = llGetSubString( m, 0, messageMaxLength-1 );     // Trim the string for safety
    m = llToLower( m );                                 // Force everything lowercase

    // Check if the message is even authorized
    if ( ! isAuthorized(id, m) ) {
        debug( 1, "Unauthorized message received from: " + (string)id );
        return [];
    }

    // Message authorized, scrub the prefix from it
    m = llStringTrim( llGetSubString(m, commandLength, -1), STRING_TRIM_HEAD );

    // Parse it to a list, and return it
    cmd = llParseString2List( m, ["|"], [] );
    debug( 2, "cmd: ["+llDumpList2String(cmd,"|")+"]" );
    return cmd;
}


// initializeNotecards():
// Reset the notecard subsystem, and begin the process of loading and processing the notecards.
// process continues via the dataserver
initializeNotecards()
{
    // Reset the notecard subsystems, and any dependent on notecard settings
    controlSettingsSubsystem    = OFF;
    lightingSettingsSubsystem   = OFF;
    commSubsystem               = OFF;

    // Empty old settings data
    controlSettings     = [];
    lightingSettings    = [];

    // Start by loading the control notecard
    controlSettingsSubsystem    = INIT;
    loadNotecard( notecardControl );
    // Continues in the dataserver
}


// loadNotecard(string):
// Start the process of loading the specified notecard into the notecardLines list
// This gets continued with processNotecard(string), called from the dataserver event
// and parseControlSettings(list) and parseLightingSettings(list), also called from the
// dataserver event
loadNotecard( string name )
{
    key notecardKey = llGetInventoryKey( name );   // Find the notecard
    
    // Make sure the notecard is located, if not, exit function with an error
    if ( notecardKey == NULL_KEY ) {
        error( "Notecard not found, '"+name+"', is it in the light's contents?" );
        return;
    }
    
    // Reset all the notecard global variables to prepare to load the new notecard
    notecardLines       = [];       // Empty the list of lines
    notecardName        = name;     // Save the name of the currently loading notecard
    notecardCurLine     = 0;        // Current line is 0
    notecardNumLines    = 0;        // We learn this when it's done reading
    debug( 2, "Loading notecard " + name );
    
    // Query the dataserver for the first line of the notecard
    notecardHandle = llGetNotecardLine( notecardName, notecardCurLine );
}

// processNotecard(string):
// Process the next line of the notecard being loaded, as passed by the dataserver,
// event, and continue loading more lines until we're done
processNotecard( string newline )
{
    // Check if we've run out of file, act accordingly
    if ( newline == EOF ) {
        notecardNumLines    = notecardCurLine;  // Save how long the notecard is
        notecardCurLine     = 0;                // Restart pointer to beginning of file
        
        if ( debugLevel >= 3 ) {        // Wrap resource-intensive debug command
            debug(3,"Loaded notecard: \n"+llDumpList2String(notecardLines,"\n") );
        }
        finalizeNotecard();             // Finialize this notecard, and do what's next
        return;     // And we're done
    }

    notecardLines += [newline]; // Append the new line to the program list
    notecardCurLine++;          // Increment the current line
    
    // Query the dataserver for the next line of the notecard
    notecardHandle = llGetNotecardLine( notecardName, notecardCurLine );
}

// list strideNotecard(list):
// Prune comments and blank lines from the notecard, and conver the rest into a strided
// list of parameters and the string representation of their values
list strideNotecard( list n )
{
    list out    = [];   // The output settings list
    string l;           // The current line
    list line   = [];   // The split current line
    integer i;          // The line number we're examining 
    integer comment;    // The location in the line of commentPrefix, if any
    string param;       // The current parameter
    string val;         // The value of the current parameter

    // Is this processing the control settings notecard?  If not it's the lighting settings card
    integer isControl   = ( controlSettingsSubsystem == INIT );

    for ( i=0; i<notecardNumLines; ++i ) {
        l = llList2String( notecardLines, i );  // Read the next line of the notecard
        l = preprocessString( l );              // Preprocess it

        line = llParseString2List( l, ["="], [""] );    // Break up the line on the equals sign
        if ( llGetListLength(line) == 2 ) {             // Must be exactly 2 in list, param & value
            // Extract (& trim) the parameter and the value from the line
            param   = llStringTrim( llList2String(line,0), STRING_TRIM_TAIL );
            val     = llStringTrim( llList2String(line,1), STRING_TRIM_HEAD );

            // ~~ Make sure parameters are valid ~~

            out += [ param, val ];  // Append the new parameter and value to the list
            // And on to the next line...
        } else {
            // If not, be quiet unless debugging
            if ( debugLevel >= 2 ) {
                if( llStringLength(l) ) {               // Ignore blank lines
                    string card = "lighting";
                    if (isControl) card = "control";
                    debug(2, "Error reading line " + (string)i + " of "+card+" notecard: '" + l + "'");
                }
            }
        }
    }

    return out;
}


// finalizeNotecard():
// Close out the recently loaded notecard, pruning comments and blank lines, storing the info where
// it needs to go, and move onto the next notecard.
finalizeNotecard()
{
    // Is this the control settings notecard?
    if ( controlSettingsSubsystem == INIT ) {
        controlSettings = strideNotecard( notecardLines );
        // ~~ Validate to make sure we have what we need in settings?

        debug( 2, "Control notecard:\n" + llDumpList2String(controlSettings,", "));

        controlSettingsSubsystem    = ON;       // Control Settings Notecard is ready to use
        lightingSettingsSubsystem   = INIT;     // Now we set up the lighting settings notecard
        loadNotecard( notecardSettings );       // Start the process of the lighting notecard
        return;
    }

    // Is this the lighting settings notecard?
    if ( lightingSettingsSubsystem == INIT ) {
        lightingSettings = strideNotecard( notecardLines );
        // ~~ Validate to make sure we have what we need in settings?

        debug( 2, "Lighting notecard:\n" + llDumpList2String(lightingSettings,", "));

        lightingSettingsSubsystem   = ON;       // Lighting Settings Notecard is ready to use
        initializeCommunication();              // Initialize the communications subsystem
        llOwnerSay( scriptName + " online");    // Report to owner that we've successfully started
        return;
    }

    // I'm lost, complain to owner
    error( "finalizeNotecard() called with no notecard loading.");
}






// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * Command Processing Functions
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

// processPingCmd():        Send a simple acknowledgement back to the owner
processPingCmd()
{
    llOwnerSay( "Ack!" );
}


// processStatusCmd():      Send a status report to the owner
processStatusCmd()
{
    llOwnerSay( "~~status report goes here~~" );
}


// processOnCmd():          Turn the light on
processOnCmd()
{
    light = ON;
    llOwnerSay( "~~clicks on~~" );
}


// processOffCmd():         Turn the light off
processOffCmd()
{
    light = OFF;
    llOwnerSay( "~~clicks off~~" );
}


// processToggleCmd():      Toggle the light between on and off
processToggleCmd()
{
    llOwnerSay( "~~toggle light~~" );
    if ( light ) {          // The light is on, turn it off
        processOffCmd();
    } else {                // The light is off, turn it on again
        processOnCmd();
    }
}


// processControlMessage(list):
// Process a pre-parsed message list as a control command
processControlMessage( list cmd )
{
    // The first element is the command, the rest parameters
    string command = llList2String( cmd, 0 );

    // Process a ping command
    if ( command == "ping" ) {
        processPingCmd();           // Process the command
        return;                     // And we're done
    }

    // Process a status command
    if ( command == "status" ) {
        processStatusCmd();         // Process the command
        return;                     // And we're done
    }

    llOwnerSay( "Unknown control command: '"+command+"'" );
}


// processSwitchMessage(list):
// Process a pre-parsed message list as a switch command
processSwitchMessage( list cmd )
{
    // The first element is the command, the rest parameters
    string command = llList2String( cmd, 0 );

    // Process a ping command
    if ( command == "ping" ) {
        processPingCmd();           // Process the command
        return;                     // And we're done
    }

    // Process an on command
    if ( command == "on" ) {
        processOnCmd();             // Process the command
        return;                     // And we're done
    }

    // Process an off command
    if ( command == "off" ) {
        processOffCmd();            // Process the command
        return;                     // And we're done
    }

    // Process a toggle command
    if ( command == "toggle" ) {
        processToggleCmd();         // Process the command
        return;                     // And we're done
    }

    llOwnerSay( "Unknown switch command: '"+command+"'" );    
}



// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * Event Handlers
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

default
{

    // state_entry(): Called when script is reset or changed
    state_entry()
    {
        scriptName = software + " v" + version;     // Calculate the full name of this script
        debug( 1, scriptName + " initializing..." );

        commandLength = llStringLength( commandPrefix );    // Store the length of the command prefix
        commentLength = llStringLength( commentPrefix );    // Store the length of the comment prefix

        initializeNotecards();                      // Load and process the notecards

        // ~~ Move the rest to further down the notecard pipeline?
        //~~initializeCommunication();                  // Set up communications subsystem
    }


    // on_rez( integer ): Called when object is rezzed (after state_entry)
    on_rez( integer start_param )
    {
        initializeCommunication();                  // Set up communications subsystem        
    }


    // dataserver(key,string): Used for Reading information from the notecards
    dataserver( key query_id, string data )
    {
        // If we're receiving a new line from a "load" command
        if ( query_id == notecardHandle ) {
            processNotecard( data );        // Process the new line of data
            return;                         // And we're done for now
        }
    }
    
    
    // listen( integer, string, key, string ): Handle incomming communications
    listen( integer channel, string name, key id, string message )
    {
        // Make sure we're ready to listen
        if ( commSubsystem != ON )    return;

        string m;                   // Store the processed message
        integer auth = FALSE;       // Whether or not it's an authorized command
        list cmd = [];              // Store the parsed command

        // Process control communications
        if ( channel == controlChannel ) {
            debug( 2, "Control: '" + message + "'" );

            // Handle the message, if all checks out return a list with the parsed message in it
            cmd = handleMessage( id, message );

            // Process the returned command list, as a control command
            processControlMessage( cmd );

            return;     // And we're done
        }

        // Process switch communications
        if ( channel == switchChannel ) {
            debug( 2, "Switch: '" + message + "'" );

            // Handle the message, if all checks out return a list with the parsed message in it
            cmd = handleMessage( id, message );

            // Process the returned command list, as a switch command
            processSwitchMessage( cmd );

            return;     // And we're done
        }
    }
}
