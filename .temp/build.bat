REM make book
cd guide_book
mdbook clean
mdbook build

REM build site directory
cd ..\
md .\.temp
cd .\.temp
md .\guide
cd ..\guide_book
xcopy "book\*" "..\.temp\guide" /E /I /Y

