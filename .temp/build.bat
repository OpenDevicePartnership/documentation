cd bookshelf
cd ".\Shelf 1 Getting Started\"
cd overview
mdbook build
cd ..\uefi 
mdbook build

cd "..\..\Shelf 2 Examples\"
cd qemu
mdbook build
cd "..\Embedded Services\"
mdbook build
cd "..\How To Build a Modern Laptop\"
mdbook build

cd "..\..\Shelf 3 Support\"
mdbook build

cd "..\Shelf 4 Specifications\"
cd "EC Interface"
mdbook build

REM build site directory
cd ..\..\..
md .\.temp
cd .\.temp
md .\site
cd .\site
md .\1
md .\2
md .\3  
md .\4
cd ..\..\bookshelf
cd "Shelf 1 Getting Started"
xcopy "overview\book\*" "..\..\.temp\site\1\overview" /E /I /Y
xcopy "uefi\book\*" "..\..\.temp\site\1\uefi" /E /I /Y
cd "../Shelf 2 Examples"
xcopy "qemu\book\*" "..\..\.temp\site\2\qemu" /E /I /Y
xcopy "Embedded Services\book\*" "..\..\.temp\site\2\embedded_services" /E /I /Y
xcopy "How To Build a Modern Laptop\book\*" "..\..\.temp\site\2\how_to_build_a_modern_laptop" /E /I /Y
cd "..\Shelf 3 Support"
xcopy "book\*" "..\..\.temp\site\3\support" /E /I /Y
cd "..\Shelf 4 Specifications"
xcopy "EC Interface\book\*" "..\..\.temp\site\4\ec_interface" /E /I /Y
cd ../..
copy .\library.html .\.temp\site\library.html /Y

