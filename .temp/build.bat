REM make book
md .temp
md .temp\guide
cd guide_book
mdbook clean
mdbook build
REM move into place
xcopy "book\*" ".\..\.temp\guide" /E /I /Y
