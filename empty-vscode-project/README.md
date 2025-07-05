# Empty VSCode Project

This is an empty VSCode project that can be used as a starting point for your own projects.
You can build this project as is and it will produice a small executable called 'main' which can be executed.
The executable just switches off the amiga operating system and displays a multi-colour background.


The 'amiga assembly' plugin can create an example workspace for you to use also.

    - Using the command pallette...
    - start typing 'amiga assembly', you should see 'Amiga Assembly: Create Example Workspace'

Or you can just copy & paste this folder and rename the output files.

Its worth taking a look at the files locarted within the .vscode folder as the files within control the build process and the execution environment when testing your builds.

    - .vscode
        - launch.json       
            - configurations for the execution of your code.
            - typically 2 configurations (Debug and Launch) per emulator type.
            - references the built executable file **may need to alter this if you change the name of the output build file**
            - you can add new configurations using the VSCode command pallette.
            - can be used to set up the emulation environment in which for your code to execute. 
            - default configurations are fine unless you require anything out of the ordinary.
        - tasks.json        
            - configurations for the build of your code.
            - default configurations are fine unless you need to alter the build process (e.g. building for absolute memory address)
            - contains the reference to you main source file to build and the output file name for the built code.
                - NB. you will need to alter the **launch.json** file and the **/uae/s/startup-sequence** files if you change the output exec name.

<br/>
The **uae** folder contains the file system for the emulator environment. By default is contains the following folders and files.
    - /uae
        - /c
            - This is the default folder name for comands (add your own supporting cli commands in here - not required unless you are doing something out of ther ordinary)
        - /s
            - This folder contains the start up script (i.e. which command to run on start)
            - set this to the name of your output executable
        - main (output exe)
            - the build executable of your project (if you renamed it in the config files above then it will be called that name.)

