    state("Darkenstein3D") { }
    state("Darkenstein 3-D Demo") { }

    startup
    {
        // Load asl-help binary and instantiate it - will inject code into the asl in the background
        Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");

        vars.Helper.LoadSceneManager = true;
        vars.Helper.GameName = "Darkenstein 3D";
        vars.Helper.AlertLoadless();

        #region TextComponent
        //Dictionary to cache created/reused layout components by their left-hand label (Text1)
        vars.lcCache = new Dictionary<string, LiveSplit.UI.Components.ILayoutComponent>();
        //Function to set (or update) a text component
        vars.SetText = (Action<string, object>)((text1, text2) =>
    {
        const string FileName = "LiveSplit.Text.dll";
        LiveSplit.UI.Components.ILayoutComponent lc;

        //Try to find an existing layout component with matching Text1 (label)
        if (!vars.lcCache.TryGetValue(text1, out lc))
        {
            lc = timer.Layout.LayoutComponents.Reverse().Cast<dynamic>()
                .FirstOrDefault(llc => llc.Path.EndsWith(FileName) && llc.Component.Settings.Text1 == text1)
                ?? LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent(FileName, timer);

            //Cache it for later reference
            vars.lcCache.Add(text1, lc);
        }

        //If it hasn't been added to the layout yet, add it
        if (!timer.Layout.LayoutComponents.Contains(lc))
            timer.Layout.LayoutComponents.Add(lc);

        //Set the label (Text1) and value (Text2) of the text component
        dynamic tc = lc.Component;
        tc.Settings.Text1 = text1;
        tc.Settings.Text2 = text2.ToString();
    });

        //Function to remove a single text component by its label
        vars.RemoveText = (Action<string>)(text1 =>
    {
        LiveSplit.UI.Components.ILayoutComponent lc;

        //If it's cached, remove it from the layout and the cache
        if (vars.lcCache.TryGetValue(text1, out lc))
        {
            timer.Layout.LayoutComponents.Remove(lc);
            vars.lcCache.Remove(text1);
        }
    });

        //Function to remove all text components that were added via this script
        vars.RemoveAllTexts = (Action)(() =>
    {
        //Remove each one from the layout
        foreach (var lc in vars.lcCache.Values)
            timer.Layout.LayoutComponents.Remove(lc);

        //Clear the cache
        vars.lcCache.Clear();
    });
    #endregion

    #region setting creation
    dynamic[,] _settings =
    {
        { "SplitOptions",       true,  "Autosplit Options", null },
        { "LevelSplits",        true,  "Level Splits: Autosplits when HP goes to 10000 at end of level", "SplitOptions" },
        { "UnityInfo",          true,  "Unity Scene Info",                     null },
            { "LScene Name: ",  false, "Name of Loading Scene",                "UnityInfo" },
            { "AScene Name: ",  true,  "Name of Active Scene",                 "UnityInfo" },
        { "DebugInfo",          false, "Debug Info",                           null },
            { "placeholder",    false, "placeholder",                          "DebugInfo" },
    };
    vars.Helper.Settings.Create(_settings);
    #endregion

    //Creating the setting for the episode names to sit under
    settings.Add("Levels", true, "All Levels");
    //Dictionary containing all of the episodes that can be split on	
	vars.Levels = new Dictionary<string,string>
	{
        {"Level001",            "1. God Damn Nazi Dogs"},
        {"Level002",            "2. Don't Drop The Soap"},
        {"Level003",            "3. Catacomb Raider"},
        {"Level004",            "4. Tutancomeon"},
        {"Level005",            "5. Hans Up!"},
        {"Level006",            "6. Pübermensch Wing"},
        {"Level007",            "7. To Moröhn Labs"},
        {"Level008",            "8. I, Manbaby"},
        {"Level009",            "9. Hypopothermia"},
        {"Level010",            "10. The U-Goat"},
        {"Level011",            "11. Oh Mummy"},
        {"Level012",            "12. The Judgement Woof"},
	};
	
    //When a new level is detected and is in the dictionary, add it as a setting value which we will use to split later on
	foreach (var script in vars.Levels) {
		settings.Add(script.Key, true, script.Value, "Levels");
	}
    }

    init
    {
        vars.SceneLoading = "";

        //Enable if having scene print issues - a custom function defined in init, the `scene` is the scene's address (e.g. vars.Helper.Scenes.Active.Address)
        vars.ReadSceneName = (Func<IntPtr, string>)(scene => {
        string name = vars.Helper.ReadString(256, ReadStringType.UTF8, scene + 0x38);
        return name == "" ? null : name;
        });

        // This is where we will load custom properties from the code
        vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
        {
        vars.Helper["placeholder"] = mono.Make<bool>("MyPlayerController", "levelStart");
        vars.Helper["isInCutscene"] = mono.Make<bool>("CutsceneManager", "isInCutscene");
        vars.Helper["isPaused"] = mono.Make<bool>("PauseManager", "GameIsPaused");
        vars.Helper["levelStart"] = mono.Make<bool>("MyPlayerController", "levelStart");
        vars.Helper["isInLevelFinishScreen"] = mono.Make<bool>("FloorComplete", "isInLevelFinishScreen");
        return true;
        });

        //Clears errors when scene and other variables are null, will get updated once they get detected
        current.placeholder = 0;
        current.Scene = "";
        current.activeScene = "";
        current.loadingScene = "";
        current.loading = false;
        current.levelStart = false;

    //Helper function that sets or removes text depending on whether the setting is enabled - only works in `init` or later because `startup` cannot read setting values
        vars.SetTextIfEnabled = (Action<string, object>)((text1, text2) =>
    {
        if (settings[text1])            //If the matching setting is checked
            vars.SetText(text1, text2); //Show the text
        else
            vars.RemoveText(text1);     //Otherwise, remove it
    });
    }

    update
    {
        vars.Helper.Update();
		vars.Helper.MapPointers();

        //Get the current active scene's name and set it to `current.activeScene` - sometimes, it is null, so fallback to old value
        current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;
        //Usually the scene that's loading, a bit jank in this version of asl-help
        current.loadingScene = vars.Helper.Scenes.Loaded[0].Name ?? current.loadingScene;
        if(!String.IsNullOrWhiteSpace(vars.Helper.Scenes.Active.Name))    current.activeScene = vars.Helper.Scenes.Active.Name;
        if(!String.IsNullOrWhiteSpace(vars.Helper.Scenes.Loaded[0].Name))    current.loadingScene = vars.Helper.Scenes.Loaded[0].Name;

        //Log changes to properties
        if(old.activeScene != current.activeScene) {vars.Log("activeScene: " + old.activeScene + " -> " + current.activeScene);}
        if(old.loadingScene != current.loadingScene) {vars.Log("loadingScene: " + old.loadingScene + " -> " + current.loadingScene);}

        //More text component stuff - checking for setting and then generating the text. No need for .ToString since we do that previously
        vars.SetTextIfEnabled("placeholder",current.placeholder);
        vars.SetTextIfEnabled("LScene Name: ",current.loadingScene);
        vars.SetTextIfEnabled("AScene Name: ",current.activeScene);

        //if (current.loadingScene != old.loadingScene) {vars.LoadStopwatch.Start();}
    }

    start
    {
        return old.levelStart == false && current.levelStart == true || old.activeScene == "MainMenu" && current.activeScene != "MainMenu";
    }

    split
    {
        //if the level is in the settings, has not been entered into the dictionary yet, and is not Null or White Space
        if(settings[current.activeScene] && !vars.completedSplits.Contains(current.activeScene) && !String.IsNullOrWhiteSpace(current.activeScene))
        {
            vars.completedSplits.Add(current.activeScene);
            return true;
        }
    }

    isLoading
    {
        return current.loadingScene != current.activeScene || current.isInLevelFinishScreen;
    }
