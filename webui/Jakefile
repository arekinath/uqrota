/*
 * Jakefile
 * webui
 *
 * Created by You on February 12, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

var ENV = require("system").env,
    FILE = require("file"),
    JAKE = require("jake"),
    task = JAKE.task,
    FileList = JAKE.FileList,
    app = require("cappuccino/jake").app,
    configuration = ENV["CONFIG"] || ENV["CONFIGURATION"] || ENV["c"] || "Debug",
    OS = require("os");

app ("webui", function(task)
{
    task.setBuildIntermediatesPath(FILE.join("Build", "webui.build", configuration));
    task.setBuildPath(FILE.join("Build", configuration));

    task.setProductName("webui");
    task.setIdentifier("com.yourcompany.webui");
    task.setVersion("1.0");
    task.setAuthor("Your Company");
    task.setEmail("feedback @nospam@ yourcompany.com");
    task.setSummary("webui");
    task.setSources((new FileList("**/*.j")).exclude(FILE.join("Build", "**")));
    task.setResources(new FileList("Resources/**"));
    task.setIndexFilePath("index.html");
    task.setInfoPlistPath("Info.plist");

    if (configuration === "Debug")
        task.setCompilerFlags("-DDEBUG -g");
    else
        task.setCompilerFlags("-O");
});

function printResults(configuration)
{
    print("----------------------------");
    print(configuration+" app built at path: "+FILE.join("Build", configuration, "webui"));
    print("----------------------------");
}

task ("default", ["webui"], function()
{
    printResults(configuration);
});

task ("build", ["default"]);

task ("debug", function()
{
    ENV["CONFIGURATION"] = "Debug";
    JAKE.subjake(["."], "build", ENV);
});

task ("release", function()
{
    ENV["CONFIGURATION"] = "Release";
    JAKE.subjake(["."], "build", ENV);
});

task ("run", ["debug"], function()
{
    OS.system(["open", FILE.join("Build", "Debug", "webui", "index.html")]);
});

task ("run-release", ["release"], function()
{
    OS.system(["open", FILE.join("Build", "Release", "webui", "index.html")]);
});

task ("deploy", ["release"], function()
{
    FILE.mkdirs(FILE.join("Build", "Deployment", "webui"));
    OS.system(["press", "-f", FILE.join("Build", "Release", "webui"), FILE.join("Build", "Deployment", "webui")]);
    printResults("Deployment")
});
