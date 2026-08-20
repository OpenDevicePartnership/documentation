REM make book
md .temp
md .temp\guide
md .temp\tracks  
cd guide_book
mdbook clean
mdbook build
REM move into place
xcopy "book\*" ".\..\.temp\guide" /E /I /Y

REM copy the common toml and mermaid files
copy ".\book.toml" "..\tracks\contributor\" /Y
copy ".\mermaid*" "..\tracks\contributor\" /Y
copy ".\book.toml" "..\tracks\embedded_controller\" /Y    
copy ".\mermaid*" "..\tracks\embedded_controller\" /Y
copy ".\book.toml" "..\tracks\integrator\" /Y
copy ".\mermaid*" "..\tracks\integrator\" /Y
copy ".\book.toml" "..\tracks\patina\" /Y 
copy ".\mermaid*" "..\tracks\patina\" /Y
copy ".\book.toml" "..\tracks\security\" /Y
copy ".\mermaid*" "..\tracks\security\" /Y
copy ".\book.toml" "..\tracks\value_proposition\" /Y
copy ".\mermaid*" "..\tracks\value_proposition\" /Y

REM copy content shared across tracks
xcopy ".\src\why\*" "..\tracks\value_proposition\src\why" /E /I /Y
xcopy ".\src\intro\concepts\patina.md" "..\tracks\patina\src\patina_concepts.md" /E /I /Y

copy ".\src\intro\concepts\Embedded_controller.md" "..\tracks\embedded_controller\src\general.md" /Y
copy ".\src\architecture\embedded_controller.md" "..\tracks\embedded_controller\src\architecture.md" /Y
copy ".\src\architecture\ec_components.md" "..\tracks\embedded_controller\src\component_arch.md" /Y
copy ".\src\architecture\ec_services.md" "..\tracks\embedded_controller\src\ec_services_arch.md" /Y
md "..\tracks\embedded_controller\src\images"
copy ".\src\intro\concepts\images\simplified_layers.png" "..\tracks\embedded_controller\src\images\simplified_layers.png" /Y
copy ".\src\intro\concepts\images\odp_arch.png" "..\tracks\embedded_controller\src\images\odp_arch.png" /Y
copy ".\src\intro\concepts\EC_Services.md" "..\tracks\embedded_controller\src\secure_ec_services.md" /Y

copy ".\src\why\secure_trust.md" "..\tracks\security\src\secure_trust.md" /Y
copy ".\src\architecture\security_architecture.md" "..\tracks\security\src\security_architecture.md" /Y
copy ".\src\architecture\secure_boot.md" "..\tracks\security\src\secure_boot.md" /Y
copy ".\src\architecture\secure_firmware_updates.md" "..\tracks\security\src\secure_firmware_updates.md" /Y



REM make all track books and copy into place
cd ..\tracks\contributor
mdbook clean                
mdbook build
xcopy "book\*" "..\..\.temp\tracks\contributor" /E /I /Y
cd ..\embedded_controller
mdbook clean
mdbook build
xcopy "book\*" "..\..\.temp\tracks\embedded_controller" /E /I /Y
cd ..\integrator
mdbook clean        
mdbook build
xcopy "book\*" "..\..\.temp\tracks\integrator" /E /I /Y
cd ..\patina
mdbook clean
mdbook build
xcopy "book\*" "..\..\.temp\tracks\patina" /E /I /Y
cd ..\security
mdbook clean    
mdbook build
xcopy "book\*" "..\..\.temp\tracks\security" /E /I /Y
cd ..\value_proposition
mdbook clean    
mdbook build   
xcopy "book\*" "..\..\.temp\tracks\value_proposition" /E /I /Y
