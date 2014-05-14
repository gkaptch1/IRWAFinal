Chandler Fuller - cfulle12@jhu.edu
Gabriel Kaptchuk - gkaptch1@jhu.edu
Information Retrival and Web Agents 
Final Project


Recepe Finder
-------------------

We have constructed a Web crawler that explores AllRecipes.com for recepes you might enjoy.

The program takes in a link of a text file with links to recipes that you like, and crawls though the web looking for others you might also like.  There are 4 such link files included with the submission under SampleLinks.
If you, like one of us, has all of your recipes in your google chrome bookmarks, you can run

$ perl input_parser.pl < ChromBookmarkExportFile

to generate a text file with all such links.

We also created a WebInterface to allow for easier interaction with the program.

NOTE: it takes a fairly long time to initialize the Users's preferneces.  We have been testing with inputs of 10 links.  Longer input files will take longer.

TO RUN INSTRUCTIONS:
--------------------

Open index.php in editor
On line 6 change the local host information to a db on you computer (or one you have access to).

Open index.php in browser (either at localhost/index.php or the location of the database you sepcified)
Upload a file with links to recipes on each line (Samples provided in SampleLinks)
OR
Enter on link in the text field (this will obviously have worse results)
Hit 'send', and wait for your results!
Press 'stop loading' or exit your broweser to kill the crawler