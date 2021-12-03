"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
const vscode = require("vscode");
const utils = require("./utils");
const projectCreation = require("./projectCreation");
const settingsManagement = require("./settingsManagement");
const runSimulator = require("./runSimulator");
// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
function activate(context) {
    console.log('LifeBoatAPI for Stormworks Lua now active. Please contact Nameous Changey if you discover issues.');
    // if config changes, we need to update the Lua library paths next time we are back on a file
    vscode.workspace.onDidChangeConfiguration((e) => {
        if (e.affectsConfiguration("lifeboatapi.stormworks.libraryPaths")
            || e.affectsConfiguration("lifeboatapi.stormworks.ignorePaths")) {
            context.workspaceState.update("lifeboatapi.lastWorkspace", null);
        }
    }, null, context.subscriptions);
    // when changing files, if the workspace changed - we need to change the library paths
    vscode.window.onDidChangeActiveTextEditor((e) => {
        const currentWorkspace = utils.getCurrentWorkspaceFolder();
        const lastWorkspace = context.workspaceState.get("lifeboatapi.lastWorkspace");
        if (currentWorkspace
            && currentWorkspace !== lastWorkspace
            && utils.isStormworksProject()) {
            context.workspaceState.update("lifeboatapi.lastWorkspace", currentWorkspace);
            settingsManagement.beginUpdateWorkspaceSettings(context).then(() => vscode.window.showInformationMessage(`Changed workspace, updated settings`));
        }
    }, null, context.subscriptions);
    // COMMAND HANDLING --------------------------------------------------------------------------------
    // Build currently Workspace
    context.subscriptions.push(vscode.commands.registerCommand('lifeboatapi.build', (folder) => {
        vscode.window.showInformationMessage('Attempt to build current project.');
        var workspace = utils.getCurrentWorkspaceFolder();
        if (workspace) {
            var config = {
                name: "Run Simulator",
                type: "lua",
                request: "launch",
                program: "${file}",
                arg: [
                // stuff for the simulator to run?
                // can't remember what config is needed
                ]
            };
            vscode.window.showInformationMessage(`Simulating file: ${utils.getCurrentWorkspaceFile()?.fsPath}`);
            vscode.debug.startDebugging(workspace, config);
        }
    }));
    // Simulate current file
    context.subscriptions.push(vscode.commands.registerCommand('lifeboatapi.simulate', () => {
        return runSimulator.beginSimulator();
    }));
    // New MC
    context.subscriptions.push(vscode.commands.registerCommand('lifeboatapi.newMCProject', () => {
        projectCreation.beginCreateNewProjectFolder(true)
            .then((folder) => vscode.commands.executeCommand("workbench.view.explorer"));
    }));
    // New Addon
    context.subscriptions.push(vscode.commands.registerCommand('lifeboatapi.newAddonProject', () => {
        projectCreation.beginCreateNewProjectFolder(false)
            .then((folder) => vscode.commands.executeCommand("workbench.view.explorer"));
    }));
}
exports.activate = activate;
// this method is called when your extension is deactivated
function deactivate() { }
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map