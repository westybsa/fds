
!  +++++++++++++++++++++++ COMPLEX_GEOMETRY ++++++++++++++++++++++++++


! Routines related to unstructured geometry and immersed boundary methods

MODULE COMPLEX_GEOMETRY

USE PRECISION_PARAMETERS
USE GLOBAL_CONSTANTS
USE MESH_VARIABLES
USE MESH_POINTERS
USE COMP_FUNCTIONS, ONLY: CHECKREAD,CHECK_XB,GET_FILE_NUMBER,SHUTDOWN
USE MEMORY_FUNCTIONS, ONLY: ChkMemErr

IMPLICIT NONE
REAL(EB), PARAMETER :: DEG2RAD=4.0_EB*ATAN(1.0_EB)/180.0_EB


!! ---------------------------------------------------------------------------------
! Start Variable declaration for CC_IBM:
! Local constants used on routines:
REAL(EB), PARAMETER :: GEOMEPS = 1.E-12_EB 

INTEGER,  PARAMETER :: LOW   = 1
INTEGER,  PARAMETER :: HIGH  = 2

INTEGER,  PARAMETER :: MDIM  = 3 ! Maximum number of spatial dimensions for a problem.
INTEGER,  PARAMETER :: IAXIS = 1
INTEGER,  PARAMETER :: JAXIS = 2
INTEGER,  PARAMETER :: KAXIS = 3
INTEGER,  PARAMETER :: NGUARD= 1 ! See if we can do with one layer of guard-cells.
INTEGER,  PARAMETER :: FCELL = 1 ! Right face index.
 
! Media definition parameters:
INTEGER,  PARAMETER :: IBM_INBOUNDCC = -3
INTEGER,  PARAMETER :: IBM_INBOUNDCF = -2
INTEGER,  PARAMETER :: IBM_GASPHASE  = -1 
INTEGER,  PARAMETER :: IBM_CUTCFE    =  0
INTEGER,  PARAMETER :: IBM_SOLID     =  1
INTEGER,  PARAMETER :: IBM_INBOUNDARY=  2
INTEGER,  PARAMETER :: IBM_UNDEFINED =-11

! Intersection type definition parameters:
INTEGER,  PARAMETER :: IBM_GG =  1 ! Gas - Gas intersection.
INTEGER,  PARAMETER :: IBM_SS =  3 ! Solid - Solid intersection.
INTEGER,  PARAMETER :: IBM_GS = -1 ! Gas to Solid intersection (as coordinate xi increases).
INTEGER,  PARAMETER :: IBM_SG =  5 ! Solid to Gas intersection (as coordinate xi increases).
INTEGER,  PARAMETER :: IBM_SGG= IBM_GG ! Single point GG intersection. Might not be needed.

! Constants used to identify variables on Eulerian grid arrays:
! Vertex centered variables:
INTEGER,  PARAMETER :: IBM_VGSC   = 1 ! Type of vertex media, IBM_GASPHASE or IBM_SOLID.
INTEGER,  PARAMETER :: IBM_NVVARS = 1 ! Number of vertex variables in MESHES(N)%IBM_VERTVAR.

! Cartesian Edge centered variables:
INTEGER,  PARAMETER :: IBM_EGSC   = 1 ! Edge media type: IBM_GASPHASE, IBM_SOLID or IBM_CUTCFE.
INTEGER,  PARAMETER :: IBM_IDCE   = 2 ! MESHES(N)%IBM_CUT_EDGE data struct entry index location. 
INTEGER,  PARAMETER :: IBM_ECRS   = 3 ! MESHES(N)%IBM_EDGECROSS data struct entry index location. 
INTEGER,  PARAMETER :: IBM_NEVARS = 3 ! Number of edge variables in MESHES(N)%IBM_ECVAR.

! Cartesian Face centered variables:
INTEGER,  PARAMETER :: IBM_FGSC   = 1 ! Face media type: IBM_GASPHASE, IBM_SOLID or IBM_CUTCFE.
!INTEGER, PARAMETER :: IBM_IDCE   = 2 ! MESHES(N)%IBM_CUT_EDGE data struct entry index location,
                                      ! IBM_INBOUNDCF type.
INTEGER,  PARAMETER :: IBM_IDCF   = 3 ! MESHES(N)%IBM_CUT_FACE data struct entry index location,
                                      ! IBM_INBOUNDCF type cut-faces.                                       
INTEGER,  PARAMETER :: IBM_NFVARS = 3 ! Number of face variables in MESHES(N)%IBM_FCVAR.

! Cartesian Cell centered variables:
INTEGER,  PARAMETER :: IBM_CGSC   = 1 ! Face media type: IBM_GASPHASE, IBM_SOLID or IBM_CUTCFE.
!INTEGER, PARAMETER :: IBM_IDCE   = 2 ! MESHES(N)%IBM_CUT_EDGE data struct entry index location,
                                      ! cut edges in Cartesian cell.
!INTEGER, PARAMETER :: IBM_IDCF   = 3 ! MESHES(N)%IBM_CUT_FACE data struct entry index location,
                                      ! IBM_INBOUNDCC type cut-faces in Cartesian cell.
INTEGER,  PARAMETER :: IBM_IDCC   = 4 ! MESHES(N)%IBM_CUT_CELL data struct entry index location,
                                      ! cut-cells in Cartesian cell.                                       
INTEGER,  PARAMETER :: IBM_NCVARS = 4 ! Number of face variables in MESHES(N)%IBM_CCVAR.

! Local integers:
INTEGER, SAVE :: IBM_NEDGECROSS, IBM_NCUTEDGE, IBM_NCUTFACE, IBM_NCUTCELL
INTEGER, SAVE :: IBM_NEDGECROSS_MESH, IBM_NCUTEDGE_MESH, IBM_NCUTFACE_MESH, IBM_NCUTCELL_MESH
INTEGER, SAVE :: ILO_CELL,IHI_CELL,JLO_CELL,JHI_CELL,KLO_CELL,KHI_CELL
INTEGER, SAVE :: ILO_FACE,IHI_FACE,JLO_FACE,JHI_FACE,KLO_FACE,KHI_FACE
INTEGER, SAVE :: NXB, NYB, NZB

INTEGER, PARAMETER :: NOD1 = 1
INTEGER, PARAMETER :: NOD2 = 2
INTEGER, PARAMETER :: NOD3 = 3

INTEGER, PARAMETER :: NODS_WSEL = 3 ! Three nodes per wet surface element (i.e. surface triangle).

INTEGER, PARAMETER :: EDG1 = 1
INTEGER, PARAMETER :: EDG2 = 2
INTEGER, PARAMETER :: EDG3 = 3

INTEGER, PARAMETER :: EDGS_WSEL = 3 ! Three edges per wet surface element.

! Intersection Body-plane data structure:
TYPE BODINT_PLANE_TYPE
   INTEGER :: NNODS     ! Number of intersection vertices.
   INTEGER :: NSGLS     ! Number of single point intersection elements.
   INTEGER :: NSEGS     ! Number of intersection segments.
   INTEGER :: NTRIS     ! Number of in-plane intersections triangles.
   REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: XYZ  ! (1:NNODS,IAXIS:KAXIS) vertex coordinates.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: SGLS ! (1:NSGLS,NOD1) connectivity list for single node elements.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: SEGS ! (1:NSEGS,NOD1:NOD2) connectivity list for segments.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: TRIS ! (1:NTRIS,NOD1:NOD3) connectivity list for triangle elements.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: INDSGL ! Wet surface triangles associated with single node elems.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: INDSEG ! Wet surface triangles associated with intersection segments.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: INDTRI ! Wet surface triangles associated with intersection triangles.
   LOGICAL,  ALLOCATABLE, DIMENSION(:)   :: X2ALIGNED ! For segments.
   LOGICAL,  ALLOCATABLE, DIMENSION(:)   :: X3ALIGNED ! For segments.
   INTEGER,  ALLOCATABLE, DIMENSION(:)   :: NBCROSS   ! Number of crossings per segment with x2,x3 grid lines.
   REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: SVAR   ! Intersections with gridlines for SEGS.
   INTEGER,  ALLOCATABLE, DIMENSION(:,:) :: SEGTYPE   ! Type of SEG based on the media it separates.
END TYPE BODINT_PLANE_TYPE

INTEGER, SAVE :: IBM_MAX_NNODS, IBM_MAX_NSGLS, IBM_MAX_NSEGS, IBM_MAX_NTRIS,       &
                 IBM_MAX_WSTRIANG_SGL, IBM_MAX_WSTRIANG_SEG, IBM_MAX_WSTRIANG_TRI, &
                 IBM_MAX_NBCROSS
           
TYPE(BODINT_PLANE_TYPE) :: IBM_BODINT_PLANE

! Edge crossings data structure:
INTEGER, PARAMETER :: IBM_MAXCROSS_EDGE = 10 ! Size definition parameter. Max number of crossings per Cartesian Edge.
TYPE EDGECROSS_TYPE
   INTEGER :: NCROSS   ! Number of BODINT_PLANE segments - Cartesian edge crossings.
   REAL(EB), DIMENSION(1:IBM_MAXCROSS_EDGE)   ::  SVAR ! Locations along x2 axis of NCROSS intersections.
   INTEGER,  DIMENSION(1:IBM_MAXCROSS_EDGE)   :: ISVAR ! Type of intersection (i.e. SG, GS or GG).
   INTEGER,  DIMENSION(5)                     ::   IJK ! [ i j k N X2AXIS]
END TYPE EDGECROSS_TYPE

INTEGER, SAVE :: IBM_MAX_EDGECROSS

TYPE(EDGECROSS_TYPE), SAVE, ALLOCATABLE, DIMENSION(:), TARGET :: IBM_EDGECROSS

! Wet surface edges intersection with Cartesian cells data structure:
TYPE BODINT_CELL_TYPE
   INTEGER :: NWSEGS ! Number of wet surface edges in immersed body ibod.
   INTEGER, ALLOCATABLE, DIMENSION(:) :: NWCROSS ! Number of intersections with Cartesian grid planes. 
   REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: SVAR ! Intersection with grid planes defined by local coord s.
END TYPE BODINT_CELL_TYPE

INTEGER, SAVE :: IBM_MAX_NWCROSS

TYPE(BODINT_CELL_TYPE), SAVE :: IBM_BODINT_CELL

! Allocatable real arrays
! Grid position containers:
REAL(EB), SAVE, ALLOCATABLE, DIMENSION(:) :: XFACE,YFACE,ZFACE,XCELL,YCELL,ZCELL, &
          DXFACE,DYFACE,DZFACE,DXCELL,DYCELL,DZCELL,X1FACE,X2FACE,X3FACE,X1CELL,  & 
          X2CELL,X3CELL,DX1FACE,DX2FACE,DX3FACE,DX1CELL,DX2CELL,DX3CELL

REAL(EB), SAVE, ALLOCATABLE, DIMENSION(:,:) :: GEOM_XYZ

! x2 Intersection data containers:
INTEGER, PARAMETER :: IBM_MAXCROSS_X2 = 32
INTEGER,  SAVE :: IBM_N_CRS
REAL(EB), SAVE :: IBM_SVAR_CRS(IBM_MAXCROSS_X2)
INTEGER,  SAVE :: IBM_IS_CRS(IBM_MAXCROSS_X2)
INTEGER,  SAVE :: IBM_IS_CRS2(LOW:HIGH,IBM_MAXCROSS_X2)
REAL(EB), SAVE :: IBM_SEG_TAN(IAXIS:JAXIS,IBM_MAXCROSS_X2)
INTEGER,  SAVE :: IBM_SEG_CRS(IBM_MAXCROSS_X2)

! End Variable declaration for CC_IBM. 
!! ---------------------------------------------------------------------------------


PRIVATE
PUBLIC :: INIT_IBM,SET_CUTCELLS_3D,TRILINEAR,GETU,GETGRAD,GET_VELO_IBM,INIT_FACE, &
          READ_GEOM,READ_VERT,READ_FACE,READ_VOLU,LINKED_LIST_INSERT,&
          WRITE_GEOM,WRITE_GEOM_ALL
 
CONTAINS

! ---------------------------- SET_CUTCELLS -------------------------------------

SUBROUTINE SET_CUTCELLS_3D

IMPLICIT NONE

! Local indexes:
INTEGER :: ILO,IHI,JLO,JHI,KLO,KHI
INTEGER :: I,J,K,KK
INTEGER :: X1AXIS, X2AXIS, X3AXIS
INTEGER :: XIAXIS, XJAXIS, XKAXIS
INTEGER :: X2LO, X2HI, X3LO, X3HI
INTEGER :: X2LO_CELL, X2HI_CELL, X3LO_CELL, X3HI_CELL
INTEGER :: ISTR, IEND, JSTR, JEND, KSTR, KEND
INTEGER :: NM

! Miscellaneous:
REAL(EB), DIMENSION(MDIM) :: PLNORMAL
INTEGER,  DIMENSION(MDIM) :: INDX1
REAL(EB) :: X1PLN, X3RAY
REAL(EB) :: DX2_MIN, DX3_MIN
LOGICAL :: TRI_ONPLANE_ONLY
LOGICAL, SAVE :: FIRST_CALL = .TRUE.

! Reset variables:
IBM_NEDGECROSS = 0
IBM_NCUTEDGE   = 0
IBM_NCUTFACE   = 0
IBM_NCUTCELL   = 0

IF (N_GEOMETRY == 0) RETURN

IF (FIRST_CALL) THEN
   
   ! Initialize GEOMETRY fields used by CC_IBM:
   CALL IBM_INIT_GEOM
   
   FIRST_CALL = .FALSE.
   
ENDIF


! Main Loop over Meshes
MAIN_MESH_LOOP : DO NM=1,NMESHES
   
   IF (PROCESS(NM)/=MYID) CYCLE
   
   ! Mesh sizes:
   NXB=MESHES(NM)%IBAR
   NYB=MESHES(NM)%JBAR
   NZB=MESHES(NM)%KBAR
   
   ! X direction bounds:
   ILO_FACE = 0                    ! Low mesh boundary face index.
   IHI_FACE = MESHES(NM)%IBAR      ! High mesh boundary face index.
   ILO_CELL = ILO_FACE + FCELL     ! First internal cell index. See notes.
   IHI_CELL = IHI_FACE + FCELL - 1 ! Last internal cell index.   
   ISTR     = ILO_FACE - NGUARD    ! Allocation start x arrays.
   IEND     = IHI_FACE + NGUARD    ! Allocation end x arrays.
      
   ! Y direction bounds:
   JLO_FACE = 0                    ! Low mesh boundary face index.
   JHI_FACE = MESHES(NM)%JBAR      ! High mesh boundary face index.
   JLO_CELL = JLO_FACE + FCELL     ! First internal cell index. See notes.
   JHI_CELL = JHI_FACE + FCELL - 1 ! Last internal cell index.   
   JSTR     = JLO_FACE - NGUARD    ! Allocation start y arrays.
   JEND     = JHI_FACE + NGUARD    ! Allocation end y arrays.
   
   ! Z direction bounds:
   KLO_FACE = 0                    ! Low mesh boundary face index.
   KHI_FACE = MESHES(NM)%KBAR      ! High mesh boundary face index.
   KLO_CELL = KLO_FACE + FCELL     ! First internal cell index. See notes.
   KHI_CELL = KHI_FACE + FCELL - 1 ! Last internal cell index.   
   KSTR     = KLO_FACE - NGUARD    ! Allocation start z arrays.
   KEND     = KHI_FACE + NGUARD    ! Allocation end z arrays.   
   
   ! Define grid arrays for this mesh:
   ! Populate position and cell size arrays: Uniform grid implementation.
   ! X direction:
   ALLOCATE(DXCELL(ISTR:IEND)); DXCELL(ILO_CELL-1:IHI_CELL+1)= MESHES(NM)%DX(ILO_CELL-1:IHI_CELL+1)
   ALLOCATE(DXFACE(ISTR:IEND)); DXFACE(ILO_FACE:IHI_FACE)= MESHES(NM)%DXN(ILO_FACE:IHI_FACE)
   DXFACE(ILO_FACE-1)=DXFACE(ILO_FACE); DXFACE(IHI_FACE+1)=DXFACE(IHI_FACE)
   ALLOCATE(XCELL(ISTR:IEND));  XCELL = 1._EB/GEOMEPS ! Initialize huge.
   XCELL(ILO_CELL-1:IHI_CELL+1) = MESHES(NM)%XC(ILO_CELL-1:IHI_CELL+1)
   ALLOCATE(XFACE(ISTR:IEND));  XFACE = 1._EB/GEOMEPS ! Initialize huge.
   XFACE(ILO_FACE:IHI_FACE) = MESHES(NM)%X(ILO_FACE:IHI_FACE)
   XFACE(ILO_FACE-1)        = XFACE(ILO_FACE) - DXCELL(ILO_FACE+FCELL-1)
   XFACE(IHI_FACE+1)        = XFACE(IHI_FACE) - DXCELL(IHI_FACE+FCELL)
   
   ! Y direction:
   ALLOCATE(DYCELL(JSTR:JEND)); DYCELL(JLO_CELL-1:JHI_CELL+1)= MESHES(NM)%DY(JLO_CELL-1:JHI_CELL+1)
   ALLOCATE(DYFACE(JSTR:JEND)); DYFACE(JLO_FACE:JHI_FACE)= MESHES(NM)%DYN(JLO_FACE:JHI_FACE)
   DYFACE(JLO_FACE-1)=DYFACE(JLO_FACE); DYFACE(JHI_FACE+1)=DYFACE(JHI_FACE)
   ALLOCATE(YCELL(JSTR:JEND));  YCELL = 1._EB/GEOMEPS ! Initialize huge.
   YCELL(JLO_CELL-1:JHI_CELL+1) = MESHES(NM)%YC(JLO_CELL-1:JHI_CELL+1)
   ALLOCATE(YFACE(JSTR:JEND));  YFACE = 1._EB/GEOMEPS ! Initialize huge.
   YFACE(JLO_FACE:JHI_FACE) = MESHES(NM)%Y(JLO_FACE:JHI_FACE)
   YFACE(JLO_FACE-1)        = YFACE(JLO_FACE) - DYCELL(JLO_FACE+FCELL-1)
   YFACE(JHI_FACE+1)        = YFACE(JHI_FACE) - DYCELL(JHI_FACE+FCELL)
   
   ! Z direction:
   ALLOCATE(DZCELL(KSTR:KEND)); DZCELL(KLO_CELL-1:KHI_CELL+1)= MESHES(NM)%DZ(KLO_CELL-1:KHI_CELL+1)
   ALLOCATE(DZFACE(KSTR:KEND)); DZFACE(KLO_FACE:KHI_FACE)= MESHES(NM)%DZN(KLO_FACE:KHI_FACE)
   DZFACE(KLO_FACE-1)=DZFACE(KLO_FACE); DZFACE(KHI_FACE+1)=DZFACE(KHI_FACE)
   ALLOCATE(ZCELL(KSTR:KEND));  ZCELL = 1._EB/GEOMEPS ! Initialize huge.
   ZCELL(KLO_CELL-1:KHI_CELL+1) = MESHES(NM)%ZC(KLO_CELL-1:KHI_CELL+1)
   ALLOCATE(ZFACE(KSTR:KEND));  ZFACE = 1._EB/GEOMEPS ! Initialize huge.
   ZFACE(KLO_FACE:KHI_FACE) = MESHES(NM)%Z(KLO_FACE:KHI_FACE)
   ZFACE(KLO_FACE-1)        = ZFACE(KLO_FACE) - DZCELL(KLO_FACE+FCELL-1)
   ZFACE(KHI_FACE+1)        = ZFACE(KHI_FACE) - DZCELL(KHI_FACE+FCELL)
   
   ! Initialize CC_IBM arrays for mesh NM:
   ! Vertices:
   IF (.NOT. ALLOCATED(MESHES(NM)%VERTVAR)) &
      ALLOCATE(MESHES(NM)%VERTVAR(ISTR:IEND,JSTR:JEND,KSTR:KEND,IBM_NVVARS))
   MESHES(NM)%VERTVAR = 0
   MESHES(NM)%VERTVAR(:,:,:,IBM_VGSC) = IBM_GASPHASE
   
   ! Cartesian Edges:
   IF (.NOT. ALLOCATED(MESHES(NM)%ECVAR)) &
      ALLOCATE(MESHES(NM)%ECVAR(ISTR:IEND,JSTR:JEND,KSTR:KEND,IBM_NEVARS,MDIM))
   MESHES(NM)%ECVAR = 0
   MESHES(NM)%ECVAR(:,:,:,IBM_EGSC,:) = IBM_GASPHASE
   
   ! Cartesian Faces:
   IF (.NOT. ALLOCATED(MESHES(NM)%FCVAR)) &
      ALLOCATE(MESHES(NM)%FCVAR(ISTR:IEND,JSTR:JEND,KSTR:KEND,IBM_NFVARS,MDIM))
   MESHES(NM)%FCVAR = 0
   MESHES(NM)%FCVAR(:,:,:,IBM_FGSC,:) = IBM_GASPHASE
   
   ! Cartesian cells:
   IF (.NOT. ALLOCATED(MESHES(NM)%CCVAR)) &
      ALLOCATE(MESHES(NM)%CCVAR(ISTR:IEND,JSTR:JEND,KSTR:KEND,IBM_NCVARS))
   MESHES(NM)%CCVAR = 0
   MESHES(NM)%CCVAR(:,:,:,IBM_CGSC) = IBM_GASPHASE
   
   ! Define CUT_EDGE, CUT_FACE and CUT_CELL arrays size for this mesh, and allocate:
   
   !Work Here:
   
   
   ! Reset Local variables:
   IBM_NEDGECROSS_MESH = 0
   IBM_NCUTEDGE_MESH   = 0
   IBM_NCUTFACE_MESH   = 0
   IBM_NCUTCELL_MESH   = 0
   
   ! Do Loop for different x1 planes:
   X1AXIS_LOOP : DO X1AXIS=IAXIS,KAXIS
      
      SELECT CASE(X1AXIS)
       CASE(IAXIS)
          
          PLNORMAL = (/ 1._EB, 0._EB, 0._EB/)
          ILO = ILO_FACE;  IHI = IHI_FACE
          JLO = JLO_FACE;  JHI = JLO_FACE
          KLO = KLO_FACE;  KHI = KLO_FACE
          
          ! x2, x3 axes parameters:
          X2AXIS = JAXIS; X2LO = JLO_FACE; X2HI = JHI_FACE
          X3AXIS = KAXIS; X3LO = KLO_FACE; X3HI = KHI_FACE
          
          ! location in I,J,K of x2,x2,x3 axes:
          XIAXIS = IAXIS; XJAXIS = JAXIS; XKAXIS = KAXIS
          
          ! Face coordinates in x1,x2,x3 axes:
          ALLOCATE(X1FACE(ISTR:IEND),DX1FACE(ISTR:IEND))
          X1FACE = XFACE; DX1FACE = DXFACE
          ALLOCATE(X2FACE(JSTR:JEND),DX2FACE(JSTR:JEND))
          X2FACE = YFACE; DX2FACE = DYFACE
          ALLOCATE(X3FACE(KSTR:KEND),DX3FACE(KSTR:KEND))
          X3FACE = ZFACE; DX3FACE = DZFACE
          
          ! x2 cell center parameters:
          X2LO_CELL = JLO_CELL; X2HI_CELL = JHI_CELL
          ALLOCATE(X2CELL(JSTR:JEND),DX2CELL(JSTR:JEND))
          X2CELL = YCELL; DX2CELL = DYCELL
          
          ! x3 cell center parameters:
          X3LO_CELL = KLO_CELL; X3HI_CELL = KHI_CELL
          ALLOCATE(X3CELL(KSTR:KEND),DX3CELL(KSTR:KEND))
          X3CELL = ZCELL; DX3CELL = DZCELL
          
       CASE(JAXIS)
          
          PLNORMAL = (/ 0._EB, 1._EB, 0._EB/)
          ILO = ILO_FACE;  IHI = ILO_FACE
          JLO = JLO_FACE;  JHI = JHI_FACE
          KLO = KLO_FACE;  KHI = KLO_FACE
          
          ! x2, x3 axes parameters:
          X2AXIS = KAXIS; X2LO = KLO_FACE; X2HI = KHI_FACE
          X3AXIS = IAXIS; X3LO = ILO_FACE; X3HI = IHI_FACE
          
          ! location in I,J,K of x2,x2,x3 axes:
          XIAXIS = KAXIS; XJAXIS = IAXIS; XKAXIS = JAXIS
          
          ! Face coordinates in x1,x2,x3 axes:
          ALLOCATE(X1FACE(JSTR:JEND),DX1FACE(JSTR:JEND))
          X1FACE = YFACE; DX1FACE = DYFACE
          ALLOCATE(X2FACE(KSTR:KEND),DX2FACE(KSTR:KEND))
          X2FACE = ZFACE; DX2FACE = DZFACE
          ALLOCATE(X3FACE(ISTR:IEND),DX3FACE(ISTR:IEND))
          X3FACE = XFACE; DX3FACE = DXFACE
          
          ! x2 cell center parameters:
          X2LO_CELL = KLO_CELL; X2HI_CELL = KHI_CELL
          ALLOCATE(X2CELL(KSTR:KEND),DX2CELL(KSTR:KEND))
          X2CELL = ZCELL; DX2CELL = DZCELL
          
          ! x3 cell center parameters:
          X3LO_CELL = ILO_CELL; X3HI_CELL = IHI_CELL
          ALLOCATE(X3CELL(ISTR:IEND),DX3CELL(ISTR:IEND))
          X3CELL = XCELL; DX3CELL = DXCELL
          
       CASE(KAXIS)
          
          PLNORMAL = (/ 0._EB, 0._EB, 1._EB/)
          ILO = ILO_FACE;  IHI = ILO_FACE
          JLO = JLO_FACE;  JHI = JLO_FACE
          KLO = KLO_FACE;  KHI = KHI_FACE
          
          ! x2, x3 axes parameters:
          X2AXIS = IAXIS; X2LO = ILO_FACE; X2HI = IHI_FACE
          X3AXIS = JAXIS; X3LO = JLO_FACE; X3HI = JHI_FACE
          
          ! location in I,J,K of x2,x2,x3 axes:
          XIAXIS = JAXIS; XJAXIS = KAXIS; XKAXIS = IAXIS
          
          ! Face coordinates in x1,x2,x3 axes:
          ALLOCATE(X1FACE(KSTR:KEND),DX1FACE(KSTR:KEND))
          X1FACE = ZFACE; DX1FACE = DZFACE
          ALLOCATE(X2FACE(ISTR:IEND),DX2FACE(ISTR:IEND))
          X2FACE = XFACE; DX2FACE = DXFACE
          ALLOCATE(X3FACE(JSTR:JEND),DX3FACE(JSTR:JEND))
          X3FACE = YFACE; DX3FACE = DYFACE
          
          ! x2 cell center parameters:
          X2LO_CELL = ILO_CELL; X2HI_CELL = IHI_CELL
          ALLOCATE(X2CELL(ISTR:IEND),DX2CELL(ISTR:IEND))
          X2CELL = XCELL; DX2CELL = DXCELL
          
          ! x3 cell center parameters:
          X3LO_CELL = JLO_CELL; X3HI_CELL = JHI_CELL
          ALLOCATE(X3CELL(JSTR:JEND),DX3CELL(JSTR:JEND))
          X3CELL = YCELL; DX3CELL = DYCELL
          
      END SELECT
      
      
      ! Loop Coordinate Planes:
      DO K=KLO,KHI
         DO J=JLO,JHI
            DO I=ILO,IHI
               
               ! Which Plane?
               INDX1(IAXIS:KAXIS) = (/ I, J, K /)
               X1PLN = X1FACE(INDX1(X1AXIS))
               
               ! Get intersection of body on plane defined by X1PLN, normal to X1AXIS:
               DX2_MIN = MINVAL(DX2CELL(X2LO_CELL:X2HI_CELL))
               DX3_MIN = MINVAL(DX3CELL(X3LO_CELL:X3HI_CELL))
               TRI_ONPLANE_ONLY = .FALSE.
               CALL GET_BODINT_PLANE(X1AXIS,X1PLN,PLNORMAL,X2AXIS,X3AXIS,DX2_MIN,DX3_MIN,TRI_ONPLANE_ONLY)
               
               ! Test that there is an intersection:
               IF((IBM_BODINT_PLANE%NSGLS+IBM_BODINT_PLANE%NSEGS+IBM_BODINT_PLANE%NTRIS) == 0) CYCLE
               
               ! Drop if node locations outside block plane area:
               IF((X2FACE(X2LO)-MAXVAL(IBM_BODINT_PLANE%XYZ(X2AXIS,1:IBM_BODINT_PLANE%NNODS))) > GEOMEPS) CYCLE
               IF((MINVAL(IBM_BODINT_PLANE%XYZ(X2AXIS,1:IBM_BODINT_PLANE%NNODS))-X2FACE(X2HI)) > GEOMEPS) CYCLE
               IF((X3FACE(X3LO)-MAXVAL(IBM_BODINT_PLANE%XYZ(X3AXIS,1:IBM_BODINT_PLANE%NNODS))) > GEOMEPS) CYCLE
               IF((MINVAL(IBM_BODINT_PLANE%XYZ(X3AXIS,1:IBM_BODINT_PLANE%NNODS))-X3FACE(X3HI)) > GEOMEPS) CYCLE
               
               ! For plane normal to X1AXIS, shoot rays along X2AXIS on all X3AXIS gridline
               ! locations, get intersection data: Loop x3 axis locations
               DO KK=X3LO,X3HI
                  
                  ! x3 location of ray along x2, on the x2-x3 plane:
                  X3RAY = X3FACE(KK)
                  
                  ! Intersections along x2 for X3RAY x3 location:
                  CALL GET_X2INTERSECTIONS(X1AXIS,X2AXIS,X3AXIS,X3RAY)
                  
                  ! Drop x2 ray if all intersections are outside of the MESH block domain:
                  IF(IBM_N_CRS > 0) THEN
                     IF((X2FACE(X2LO)-IBM_SVAR_CRS(IBM_N_CRS)) > GEOMEPS) THEN
                        CYCLE
                     ELSEIF(IBM_SVAR_CRS(1)-X2FACE(X2HI) > GEOMEPS) THEN
                        CYCLE
                     ENDIF
                  ENDIF
                  
                  ! Now for this ray, set vertex types in MESHES(NM)%VERTVAR(:,:,:,IBM_VGSC):
                  CALL GET_X2_VERTVAR(X1AXIS,X2LO,X2HI,NM,I,KK)
                  
                  ! WORK HERE:
                  
                  
                  
               ENDDO ! KK - x3 gridlines.
               
               
               ! WORK HERE:
               
               
            ENDDO ! I index
         ENDDO ! J index
      ENDDO ! K index
      
      
      ! Deallocate local plane arrays:
      DEALLOCATE(X1FACE,X2FACE,X3FACE,X2CELL,X3CELL)
      DEALLOCATE(DX1FACE,DX2FACE,DX3FACE,DX2CELL,DX3CELL)
      
   ENDDO X1AXIS_LOOP
   
   
   
   ! WORK HERE:
   
   
   
   ! Deallocate arrays:
   ! Face centered positions and cell sizes:
   IF(ALLOCATED(XFACE)) DEALLOCATE(XFACE)
   IF(ALLOCATED(YFACE)) DEALLOCATE(YFACE)
   IF(ALLOCATED(ZFACE)) DEALLOCATE(ZFACE)
   IF(ALLOCATED(DXFACE)) DEALLOCATE(DXFACE)
   IF(ALLOCATED(DYFACE)) DEALLOCATE(DYFACE)
   IF(ALLOCATED(DZFACE)) DEALLOCATE(DZFACE)
   
   ! Cell centered positions and cell sizes:
   IF(ALLOCATED(XCELL)) DEALLOCATE(XCELL)
   IF(ALLOCATED(YCELL)) DEALLOCATE(YCELL)
   IF(ALLOCATED(ZCELL)) DEALLOCATE(ZCELL)
   IF(ALLOCATED(DXCELL)) DEALLOCATE(DXCELL)
   IF(ALLOCATED(DYCELL)) DEALLOCATE(DYCELL)
   IF(ALLOCATED(DZCELL)) DEALLOCATE(DZCELL)
   
ENDDO MAIN_MESH_LOOP


RETURN
END SUBROUTINE SET_CUTCELLS_3D


! -------------------------- GET_BODINT_PLANE -----------------------------------

SUBROUTINE GET_BODINT_PLANE(X1AXIS,X1PLN,PLNORMAL,X2AXIS,X3AXIS,DX2_MIN,DX3_MIN,TRI_ONPLANE_ONLY)


IMPLICIT NONE
INTEGER, INTENT(IN) :: X1AXIS, X2AXIS, X3AXIS
REAL(EB),INTENT(IN) :: X1PLN, DX2_MIN, DX3_MIN, PLNORMAL(MDIM)
LOGICAL, INTENT(IN) :: TRI_ONPLANE_ONLY

! Local variables:
INTEGER :: N_VERTS_TOT, N_FACES_TOT
INTEGER :: IG, IWSEL, IEDGE, INOD, ISGL, ISEG, ITRI, NINDTRI, EDGE_TRI
REAL(EB):: LEDGE, MAX_LEDGE, DXYZE(MDIM), XYZV(MDIM,NODS_WSEL)
INTEGER :: ELEM(NODS_WSEL), WSELEM(NODS_WSEL), IND_P(NODS_WSEL), NTRIS, NSEGS
REAL(EB):: MINX1V, MAXX1V, DOT1, DOT2, DOT3
LOGICAL :: OUTPLANE, INTFLG, INLIST
REAL(EB):: LN1(MDIM,NOD1:NOD2), LN2(MDIM,NOD1:NOD2)
REAL(EB):: XYZ_INT1(MDIM), XYZ_INT2(MDIM)
INTEGER :: SEG(NOD1:NOD2), EDGES(NOD1:NOD2,3), VEC3(3)
REAL(EB):: X2X3(IAXIS:JAXIS,NODS_WSEL), AREALOC
REAL(EB):: XP1(IAXIS:JAXIS), XP2(IAXIS:JAXIS), TX2P(IAXIS:JAXIS), TX3P(IAXIS:JAXIS)
REAL(EB):: NMTX2P
INTEGER :: IWSEL1, IWSEL2, ELEM1(NODS_WSEL), ELEM2(NODS_WSEL)
REAL(EB):: XYZ1(MDIM), NXYZ1(MDIM), NX3P1, N1(IAXIS:JAXIS), NMNL
REAL(EB):: XYZ2(MDIM), NXYZ2(MDIM), NX3P2, N2(IAXIS:JAXIS)
REAL(EB):: X3PVERT, PVERT(IAXIS:JAXIS), X3P1, P1CEN(IAXIS:JAXIS), X3P2, P2CEN(IAXIS:JAXIS)
INTEGER :: VCT(2)
REAL(EB):: PCT(IAXIS:JAXIS,1:2), V1(IAXIS:JAXIS), V2(IAXIS:JAXIS), CRSSNV, CTST
REAL(EB):: VEC(IAXIS:JAXIS,1:2)
INTEGER, ALLOCATABLE, DIMENSION(:,:) :: SEGAUX, INDSEGAUX, SEGTYPEAUX
REAL(EB):: X3_1, X2_1, X3_2, X2_2, SLEN, SBOD
INTEGER :: ISEG_NEW, NBCROSS

! Define BODINT_PLANE allocation sizes, hard wired for now:
! Maximum number of vertices and elements in BODINT_PLANE:
N_VERTS_TOT=0; N_FACES_TOT=0
DO IG=1,N_GEOMETRY
   N_VERTS_TOT = N_VERTS_TOT + GEOMETRY(IG)%N_VERTS
   N_FACES_TOT = N_FACES_TOT + GEOMETRY(IG)%N_FACES
ENDDO

! Conservative estimate:
IBM_MAX_NNODS = 2 * N_VERTS_TOT
IBM_MAX_NSGLS = N_VERTS_TOT
IBM_MAX_NSEGS = N_FACES_TOT
IBM_MAX_NTRIS = N_FACES_TOT

! Maximum number of wet surface triangles related to element:
IBM_MAX_WSTRIANG_SGL = 16  ! Up to 16 wstriangles related to a wet surface vertex.
IBM_MAX_WSTRIANG_SEG =  2  ! Up to two wstriangles related to a segment.
IBM_MAX_WSTRIANG_TRI =  1  ! Up to 1 wstriangle per BODINT_PLANE triangle (i.e. surface triangle 
                           ! aligned with X1PLN plane.)

! Maximum number of grid crossings on BODINT_PLANE segments:
MAX_LEDGE = GEOMEPS ! Initialize to a small number.
DO IG=1,N_GEOMETRY
   DO IWSEL=1,GEOMETRY(IG)%N_FACES
      WSELEM(NOD1:NOD3) = GEOMETRY(IG)%FACES(NODS_WSEL*(IWSEL-1)+1:NODS_WSEL*IWSEL)
      
      ! Obtain edges length, test against MAX_LEDGE:
      DO IEDGE=1,3
         
         ! DX = XYZ2 - XYZ1:
         DXYZE(IAXIS:KAXIS) = GEOMETRY(IG)%VERTS(MDIM*(WSELEM(NOD2)-1)+1:MDIM*WSELEM(NOD2)) - &
                              GEOMETRY(IG)%VERTS(MDIM*(WSELEM(NOD1)-1)+1:MDIM*WSELEM(NOD1))
         LEDGE = sqrt( DXYZE(IAXIS)**2._EB + DXYZE(JAXIS)**2._EB + DXYZE(KAXIS)**2._EB )
         
         MAX_LEDGE = MAX(MAX_LEDGE,LEDGE)
         
         WSELEM=CSHIFT(WSELEM,1)  ! Shift cyclically array by 1 entry. This rotates nodes connectivities.
                                  ! i.e: initially WSELEM=(/1,2,3/), 1st call gives WSELEM=(/2,3,1/), 2nd
                                  ! call gives WSELEM=(/3,1,2/).
         
      ENDDO
   ENDDO
 
ENDDO
IBM_MAX_NBCROSS = 2 * CEILING(MAX_LEDGE/MIN(DX2_MIN, DX3_MIN)) ! Rough estimate. Might need to increase 
                                                               ! the 2 factor.

! Now allocate IBM_BODINT_PLANE:
IBM_BODINT_PLANE%NNODS = 0
IBM_BODINT_PLANE%NSGLS = 0
IBM_BODINT_PLANE%NSEGS = 0
IBM_BODINT_PLANE%NTRIS = 0
IF ( ALLOCATED(IBM_BODINT_PLANE%XYZ)  )      DEALLOCATE(IBM_BODINT_PLANE%XYZ)
IF ( ALLOCATED(IBM_BODINT_PLANE%SGLS) )      DEALLOCATE(IBM_BODINT_PLANE%SGLS)
IF ( ALLOCATED(IBM_BODINT_PLANE%SEGS) )      DEALLOCATE(IBM_BODINT_PLANE%SEGS)
IF ( ALLOCATED(IBM_BODINT_PLANE%TRIS) )      DEALLOCATE(IBM_BODINT_PLANE%TRIS)
IF ( ALLOCATED(IBM_BODINT_PLANE%INDSGL) )    DEALLOCATE(IBM_BODINT_PLANE%INDSGL)
IF ( ALLOCATED(IBM_BODINT_PLANE%INDSEG) )    DEALLOCATE(IBM_BODINT_PLANE%INDSEG)
IF ( ALLOCATED(IBM_BODINT_PLANE%INDTRI) )    DEALLOCATE(IBM_BODINT_PLANE%INDTRI)
IF ( ALLOCATED(IBM_BODINT_PLANE%X2ALIGNED) ) DEALLOCATE(IBM_BODINT_PLANE%X2ALIGNED)
IF ( ALLOCATED(IBM_BODINT_PLANE%X3ALIGNED) ) DEALLOCATE(IBM_BODINT_PLANE%X3ALIGNED)
IF ( ALLOCATED(IBM_BODINT_PLANE%NBCROSS) )   DEALLOCATE(IBM_BODINT_PLANE%NBCROSS)
IF ( ALLOCATED(IBM_BODINT_PLANE%SVAR) )      DEALLOCATE(IBM_BODINT_PLANE%SVAR)
IF ( ALLOCATED(IBM_BODINT_PLANE%SEGTYPE) )   DEALLOCATE(IBM_BODINT_PLANE%SEGTYPE)

ALLOCATE(IBM_BODINT_PLANE%      XYZ(IAXIS:KAXIS,            IBM_MAX_NNODS))
ALLOCATE(IBM_BODINT_PLANE%     SGLS(NOD1,                   IBM_MAX_NSGLS))
ALLOCATE(IBM_BODINT_PLANE%     SEGS(NOD1:NOD2,              IBM_MAX_NSEGS))
ALLOCATE(IBM_BODINT_PLANE%     TRIS(NOD1:NOD3,              IBM_MAX_NTRIS))
ALLOCATE(IBM_BODINT_PLANE%   INDSGL(IBM_MAX_WSTRIANG_SGL+2, IBM_MAX_NSGLS))
ALLOCATE(IBM_BODINT_PLANE%   INDSEG(IBM_MAX_WSTRIANG_SEG+2, IBM_MAX_NSEGS))
ALLOCATE(IBM_BODINT_PLANE%   INDTRI(IBM_MAX_WSTRIANG_TRI+1, IBM_MAX_NTRIS))
ALLOCATE(IBM_BODINT_PLANE%X2ALIGNED(IBM_MAX_NSEGS))
ALLOCATE(IBM_BODINT_PLANE%X3ALIGNED(IBM_MAX_NSEGS))
ALLOCATE(IBM_BODINT_PLANE%  NBCROSS(IBM_MAX_NSEGS))
ALLOCATE(IBM_BODINT_PLANE%     SVAR(IBM_MAX_NBCROSS,        IBM_MAX_NSEGS))  ! Here first index is ibcross.
ALLOCATE(IBM_BODINT_PLANE%  SEGTYPE(LOW:HIGH,              IBM_MAX_NSEGS))

! write(*,*) "size(IBM_BODINT_PLANE%  SEGTYPE) =",     &
!             size(IBM_BODINT_PLANE%  SEGTYPE, dim=1), &
!             size(IBM_BODINT_PLANE%  SEGTYPE, dim=2)
! pause

! Main Loop over Geometries:
MAIN_GEOM_LOOP : DO IG=1,N_GEOMETRY
   
   ! Loop surface triangles:
   DO IWSEL =1,GEOMETRY(IG)%N_FACES
      
      WSELEM(NOD1:NOD3) = GEOMETRY(IG)%FACES(NODS_WSEL*(IWSEL-1)+1:NODS_WSEL*IWSEL)
      
      ! Triangles NODES coordinates:
      DO INOD=NOD1,NOD3
         XYZV(IAXIS:KAXIS,INOD) = GEOMETRY(IG)%VERTS(MDIM*(WSELEM(INOD)-1)+1:MDIM*WSELEM(INOD))
      ENDDO
      
      ! Find min-max x1 coordinate values:
      MINX1V = MINVAL(XYZV(X1AXIS,NOD1:NOD3))
      MAXX1V = MAXVAL(XYZV(X1AXIS,NOD1:NOD3))
      
      ! Test if triangle IWSEL crosses the X1PLN plane, or is at GEOMEPS proximity of it:
      OUTPLANE = ((X1PLN-MAXX1V) > GEOMEPS) .OR. ((MINX1V-X1PLN) > GEOMEPS)
      IF (OUTPLANE) CYCLE
      
      ! Compute simplified dot(PLNORMAL,XYZV-XYZPLANE):
      DOT1 = XYZV(X1AXIS,NOD1) - X1PLN
      DOT2 = XYZV(X1AXIS,NOD2) - X1PLN
      DOT3 = XYZV(X1AXIS,NOD3) - X1PLN
      IF ( ABS(DOT1) <= GEOMEPS ) DOT1 = 0._EB
      IF ( ABS(DOT2) <= GEOMEPS ) DOT2 = 0._EB
      IF ( ABS(DOT3) <= GEOMEPS ) DOT3 = 0._EB
      
      ! Test if IWSEL lays in X1PLN:
      IF ( (ABS(DOT1)+ABS(DOT2)+ABS(DOT3)) == 0._EB ) THEN
         
         ! Force nodes location in X1PLN plane:
         XYZV(X1AXIS,NOD1:NOD3) = X1PLN
         
         ! Index to point 1 of triangle in BODINT_PLANE%XYZ list:
         CALL GET_BODINT_NODE_INDEX(XYZV(IAXIS:KAXIS,NOD1),IND_P(NOD1))
         
         ! Index to point 2 of triangle in BODINT_PLANE%XYZ list:
         CALL GET_BODINT_NODE_INDEX(XYZV(IAXIS:KAXIS,NOD2),IND_P(NOD2))
         
         ! Index to point 3 of triangle in BODINT_PLANE%XYZ list:
         CALL GET_BODINT_NODE_INDEX(XYZV(IAXIS:KAXIS,NOD3),IND_P(NOD3))
         
         ! Do we need to test if we already have this triangle on
         ! the list? Shouldn't unless repeated -> Possibility for
         ! zero thickness.
         NTRIS = IBM_BODINT_PLANE % NTRIS + 1
         IBM_BODINT_PLANE % NTRIS = NTRIS
         IBM_BODINT_PLANE % TRIS(NOD1:NOD3,NTRIS) = IND_P
         IBM_BODINT_PLANE % INDTRI(1:2,NTRIS) = (/ IWSEL, IG /)
         
         CYCLE ! Next WSELEM
         
      ENDIF
      
      ! Test if we are looking for intersection triangles only:
      IF (TRI_ONPLANE_ONLY) CYCLE
      
      ! Case a: Typical intersections:
      ! Points 1,2 on on side of plane, point 3 on the other:
      IF ( ((DOT1 > 0._EB) .AND. (DOT2 > 0._EB) .AND. (DOT3 < 0._EB)) .OR. &
           ((DOT1 < 0._EB) .AND. (DOT2 < 0._EB) .AND. (DOT3 > 0._EB)) ) THEN
         
         ! Line 1, from node 2 to 3:
         LN1(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD2)
         LN1(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD3)
         
         CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN1,XYZ_INT1,INTFLG)
         
         !IF(.NOT. INTFLG) THEN
         !  print*, "Error GET_BODINT_PLANE: No intersection on LN1, typical 1."
         !ENDIF
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Line 2, from node 1 to 3:
         LN2(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD1)
         LN2(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD3)
         
         CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN2,XYZ_INT2,INTFLG)
         
         !IF(.NOT. INTFLG) THEN
         !  print*, "Error GET_BODINT_PLANE: No intersection on LN2, typical 1."
         !ENDIF
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Now add segment:
         NSEGS = IBM_BODINT_PLANE % NSEGS + 1
         IBM_BODINT_PLANE % NSEGS = NSEGS
         IF ( DOT1 > 0._EB ) THEN ! First case, counterclockwise p1 to p2
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ELSE
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ENDIF
         IBM_BODINT_PLANE%INDSEG(1:4,NSEGS) = (/ 1, IWSEL, 0, IG /)
         IBM_BODINT_PLANE%SEGTYPE(1:2,NSEGS)= (/ IBM_SOLID, IBM_GASPHASE /)
         
         CYCLE ! Next WSELEM
         
      ENDIF
      ! Points 2,3 on one side of plane, point 1 on the other:
      IF ( ((DOT2 > 0._EB) .AND. (DOT3 > 0._EB) .AND. (DOT1 < 0._EB)) .OR. &
           ((DOT2 < 0._EB) .AND. (DOT3 < 0._EB) .AND. (DOT1 > 0._EB)) ) THEN
         
           ! Line 1, from node 1 to 2:
           LN1(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD1)
           LN1(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD2)
           
           CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN1,XYZ_INT1,INTFLG)
           
           !IF(.NOT. INTFLG) THEN
           !  print*, "Error GET_BODINT_PLANE: No intersection on LN1, typical 2."
           !ENDIF
           
           ! Index to XYZ_INT1:
           CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
           
           ! Line 2, from node 1 to 3:
           LN2(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD1)
           LN2(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD3)
           
           CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN2,XYZ_INT2,INTFLG)
           
           !IF(.NOT. INTFLG) THEN
           !  print*, "Error GET_BODINT_PLANE: No intersection on LN2, typical 2."
           !ENDIF
           
           ! Index to XYZ_INT2:
           CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
           
           ! Now add segment:
           NSEGS = IBM_BODINT_PLANE % NSEGS + 1
           IBM_BODINT_PLANE % NSEGS = NSEGS
           IF ( DOT2 > 0._EB ) THEN ! Second case, counterclockwise p2 to p1
              IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD2), IND_P(NOD1) /)
           ELSE
              IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD1), IND_P(NOD2) /)
           ENDIF
           IBM_BODINT_PLANE%INDSEG(1:4,NSEGS) = (/ 1, IWSEL, 0, IG /)
           IBM_BODINT_PLANE%SEGTYPE(1:2,NSEGS)= (/ IBM_SOLID, IBM_GASPHASE /)
           
           CYCLE ! Next WSELEM
         
      ENDIF
      ! Points 1,3 on one side of plane, point 2 on the other:
      IF ( ((DOT1 > 0._EB) .AND. (DOT3 > 0._EB) .AND. (DOT2 < 0._EB)) .OR. &
           ((DOT1 < 0._EB) .AND. (DOT3 < 0._EB) .AND. (DOT2 > 0._EB)) ) THEN
         
           ! Line 1, from node 1 to 2:
           LN1(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD1)
           LN1(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD2)
           
           CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN1,XYZ_INT1,INTFLG)
           
           !IF(.NOT. INTFLG) THEN
           !  print*, "Error GET_BODINT_PLANE: No intersection on LN1, typical 3."
           !ENDIF
           
           ! Index to XYZ_INT1:
           CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
           
           ! Line 2, from node 2 to 3:
           LN2(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD2)
           LN2(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD3)
           
           CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN2,XYZ_INT2,INTFLG)
           
           !IF(.NOT. INTFLG) THEN
           !  print*, "Error GET_BODINT_PLANE: No intersection on LN2, typical 2."
           !ENDIF
           
           ! Index to XYZ_INT2:
           CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
           
           ! Now add segment:
           NSEGS = IBM_BODINT_PLANE % NSEGS + 1
           IBM_BODINT_PLANE % NSEGS = NSEGS
           IF ( DOT1 > 0._EB ) THEN ! Third case, counterclockwise p1 to p2
              IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD1), IND_P(NOD2) /)
           ELSE
              IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD2), IND_P(NOD1) /)
           ENDIF
           IBM_BODINT_PLANE%INDSEG(1:4,NSEGS) = (/ 1, IWSEL, 0, IG /)
           IBM_BODINT_PLANE%SEGTYPE(1:2,NSEGS)= (/ IBM_SOLID, IBM_GASPHASE /)
           
           CYCLE ! Next WSELEM
         
      ENDIF
      
      ! Case b: only one point intersection. They will be used to define
      ! Solid vertex points in case of coincidence.
      ! Point 1 is on the plane:
      IF ( (DOT1 == 0._EB) .AND. ( ((DOT2 > 0._EB) .AND. (DOT3 > 0._EB)) .OR. &
                                   ((DOT2 < 0._EB) .AND. (DOT3 < 0._EB)) ) ) THEN
         
         ! First node is an intersection point:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD1); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Add index to singles:
         ! Find if oriented segment is in list:
         INLIST = .FALSE.
         DO ISGL=1,IBM_BODINT_PLANE%NSGLS
            IF (IBM_BODINT_PLANE%SGLS(NOD1,ISGL) == IND_P(NOD1)) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (.NOT.INLIST) THEN
            ISGL = IBM_BODINT_PLANE%NSGLS + 1
            IBM_BODINT_PLANE % NSGLS = ISGL
            IBM_BODINT_PLANE % SGLS(NOD1,ISGL) = IND_P(NOD1)
            IBM_BODINT_PLANE % INDSGL(1:2,ISGL) = (/ 1, IWSEL /)
            IBM_BODINT_PLANE % INDSGL(IBM_MAX_WSTRIANG_SGL+2,ISGL) = IG
         ELSE
            NINDTRI = IBM_BODINT_PLANE % INDSGL(1,ISGL) + 1
            !IF (NINDTRI > IBM_MAX_WSTRIANG_SGL) THEN
            !   print*, "Error GET_BODINT_PLANE: number of triangles per node > IBM_MAX_WSTRIANG_SGL."
            !ENDIF
            IBM_BODINT_PLANE % INDSGL(1,ISGL) = NINDTRI
            IBM_BODINT_PLANE % INDSGL(NINDTRI+1,ISGL) = IWSEL
         ENDIF
         
         CYCLE ! Next WSELEM
         
      ENDIF
      ! Point 2 is on the plane:
      IF ( (DOT2 == 0._EB) .AND. ( ((DOT1 > 0._EB) .AND. (DOT3 > 0._EB)) .OR. &
                                   ((DOT1 < 0._EB) .AND. (DOT3 < 0._EB)) ) ) THEN
         
         ! Second node is an intersection point:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD2); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Add index to singles:
         ! Find if oriented segment is in list:
         INLIST = .FALSE.
         DO ISGL=1,IBM_BODINT_PLANE%NSGLS
            IF (IBM_BODINT_PLANE%SGLS(NOD1,ISGL) == IND_P(NOD1)) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (.NOT.INLIST) THEN
            ISGL = IBM_BODINT_PLANE%NSGLS + 1
            IBM_BODINT_PLANE % NSGLS = ISGL
            IBM_BODINT_PLANE % SGLS(NOD1,ISGL) = IND_P(NOD1)
            IBM_BODINT_PLANE % INDSGL(1:2,ISGL) = (/ 1, IWSEL /)
            IBM_BODINT_PLANE % INDSGL(IBM_MAX_WSTRIANG_SGL+2,ISGL) = IG
         ELSE
            NINDTRI = IBM_BODINT_PLANE % INDSGL(1,ISGL) + 1
            !IF (NINDTRI > IBM_MAX_WSTRIANG_SGL) THEN
            !   print*, "Error GET_BODINT_PLANE: number of triangles per node > IBM_MAX_WSTRIANG_SGL."
            !ENDIF
            IBM_BODINT_PLANE % INDSGL(1,ISGL) = NINDTRI
            IBM_BODINT_PLANE % INDSGL(NINDTRI+1,ISGL) = IWSEL
         ENDIF
         
         CYCLE ! Next WSELEM
         
      ENDIF
      ! Point 3 is on the plane:
      IF ( (DOT3 == 0._EB) .AND. ( ((DOT1 > 0._EB) .AND. (DOT2 > 0._EB)) .OR. &
                                   ((DOT1 < 0._EB) .AND. (DOT2 < 0._EB)) ) ) THEN
         
         ! Third node is an intersection point:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD3); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Add index to singles:
         ! Find if single element is in list:
         INLIST = .FALSE.
         DO ISGL=1,IBM_BODINT_PLANE%NSGLS
            IF (IBM_BODINT_PLANE%SGLS(NOD1,ISGL) == IND_P(NOD1)) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (.NOT.INLIST) THEN
            ISGL = IBM_BODINT_PLANE%NSGLS + 1
            IBM_BODINT_PLANE % NSGLS = ISGL
            IBM_BODINT_PLANE % SGLS(NOD1,ISGL) = IND_P(NOD1)
            IBM_BODINT_PLANE % INDSGL(1:2,ISGL) = (/ 1, IWSEL /)
            IBM_BODINT_PLANE % INDSGL(IBM_MAX_WSTRIANG_SGL+2,ISGL) = IG
         ELSE
            NINDTRI = IBM_BODINT_PLANE % INDSGL(1,ISGL) + 1
            !IF (NINDTRI > IBM_MAX_WSTRIANG_SGL) THEN
            !   print*, "Error GET_BODINT_PLANE: number of triangles per node > IBM_MAX_WSTRIANG_SGL."
            !ENDIF
            IBM_BODINT_PLANE % INDSGL(1,ISGL) = NINDTRI
            IBM_BODINT_PLANE % INDSGL(NINDTRI+1,ISGL) = IWSEL
         ENDIF
         
         CYCLE ! Next WSELEM
         
      ENDIF
      
      ! Case c: one node is part of the intersection:
      ! Node 1 is in the plane:
      IF ( (DOT1 == 0._EB) .AND. ( ((DOT2 > 0._EB) .AND. (DOT3 < 0._EB)) .OR. &
                                   ((DOT2 < 0._EB) .AND. (DOT3 > 0._EB)) ) ) THEN
         
         ! First node is an intersection point:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD1); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Line 2, from node 2 to 3:
         LN2(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD2)
         LN2(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD3)
         
         CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN2,XYZ_INT2,INTFLG)
         
         !IF(.NOT. INTFLG) THEN
         !  print*, "Error GET_BODINT_PLANE: No intersection on LN2, Case C 1."
         !ENDIF
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Now add segment:
         NSEGS = IBM_BODINT_PLANE % NSEGS + 1
         IBM_BODINT_PLANE % NSEGS = NSEGS
         IF ( DOT2 > 0._EB ) THEN ! Second case, counterclockwise p2 to p1
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ELSE
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ENDIF
         IBM_BODINT_PLANE%INDSEG(1:4,NSEGS) = (/ 1, IWSEL, 0, IG /)
         IBM_BODINT_PLANE%SEGTYPE(1:2,NSEGS)= (/ IBM_SOLID, IBM_GASPHASE /)
         
         CYCLE ! Next WSELEM
      
      ENDIF
      ! Node 2 is in the plane:
      IF ( (DOT2 == 0._EB) .AND. ( ((DOT1 > 0._EB) .AND. (DOT3 < 0._EB)) .OR. &
                                   ((DOT1 < 0._EB) .AND. (DOT3 > 0._EB)) ) ) THEN
         
         ! Second node is an intersection point:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD2); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Line 2, from node 1 to 3:
         LN2(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD1)
         LN2(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD3)
         
         CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN2,XYZ_INT2,INTFLG)
         
         !IF(.NOT. INTFLG) THEN
         !  print*, "Error GET_BODINT_PLANE: No intersection on LN2, Case C 2."
         !ENDIF
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Now add segment:
         NSEGS = IBM_BODINT_PLANE % NSEGS + 1
         IBM_BODINT_PLANE % NSEGS = NSEGS
         IF ( DOT1 > 0._EB ) THEN
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ELSE
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ENDIF
         IBM_BODINT_PLANE%INDSEG(1:4,NSEGS) = (/ 1, IWSEL, 0, IG /)
         IBM_BODINT_PLANE%SEGTYPE(1:2,NSEGS)= (/ IBM_SOLID, IBM_GASPHASE /)
         
         CYCLE ! Next WSELEM
         
      ENDIF
      ! Node 3 is in the plane:
      IF ( (DOT3 == 0._EB) .AND. ( ((DOT1 > 0._EB) .AND. (DOT2 < 0._EB)) .OR. &
                                   ((DOT1 < 0._EB) .AND. (DOT2 > 0._EB)) ) ) THEN
         
         ! Third node is an intersection point:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD3); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Line 2, from node 1 to 2:
         LN2(IAXIS:KAXIS,NOD1) = XYZV(IAXIS:KAXIS,NOD1)
         LN2(IAXIS:KAXIS,NOD2) = XYZV(IAXIS:KAXIS,NOD2)
         
         CALL LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LN2,XYZ_INT2,INTFLG)
         
         !IF(.NOT. INTFLG) THEN
         !  print*, "Error GET_BODINT_PLANE: No intersection on LN2, Case C 3."
         !ENDIF
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Now add segment:
         NSEGS = IBM_BODINT_PLANE % NSEGS + 1
         IBM_BODINT_PLANE % NSEGS = NSEGS
         IF ( DOT1 > 0._EB ) THEN
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ELSE
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,NSEGS) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ENDIF
         IBM_BODINT_PLANE%INDSEG(1:4,NSEGS) = (/ 1, IWSEL, 0, IG /)
         IBM_BODINT_PLANE%SEGTYPE(1:2,NSEGS)= (/ IBM_SOLID, IBM_GASPHASE /)
         
         CYCLE ! Next WSELEM
         
      ENDIF
      
      ! Case D: A triangle segment is in the plane.
      ! Intersection is line 1-2:
      IF ( (DOT1 == 0._EB) .AND. (DOT2 == 0._EB) ) THEN
         
         ! First node:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD1); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Second node:
         XYZ_INT2 = XYZV(IAXIS:KAXIS,NOD2); XYZ_INT2(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Set oriented segment regarding plane:
         IF ( DOT3 > 0._EB ) THEN
            SEG(NOD1:NOD2) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ELSE
            SEG(NOD1:NOD2) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ENDIF
         ! Find if oriented segment is in list:
         INLIST = .FALSE.
         DO ISEG=1,IBM_BODINT_PLANE%NSEGS
            ! IF ( ANY(IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) == SEG(NOD1)) .AND. &
            !      ANY(IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) == SEG(NOD2)) ) THEN
            !    INLIST = .TRUE.
            !    EXIT
            ! ENDIF
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == SEG(NOD1)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == SEG(NOD2)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == SEG(NOD2)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == SEG(NOD1)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (.NOT.INLIST) THEN
            ISEG = IBM_BODINT_PLANE%NSEGS + 1
            IBM_BODINT_PLANE%NSEGS = ISEG
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) = SEG
            EDGE_TRI = GEOMETRY(IG)%FACE_EDGES(EDG1,IWSEL) ! 1st edge: Ed1 NOD1-NOD2, Ed2 NOD2-NOD3, Ed3 NOD3-NOD1.
            VEC3(1) = GEOMETRY(IG)%EDGE_FACES(1,EDGE_TRI)
            VEC3(2) = GEOMETRY(IG)%EDGE_FACES(2,EDGE_TRI)
            VEC3(3) = GEOMETRY(IG)%EDGE_FACES(4,EDGE_TRI)
            IBM_BODINT_PLANE%INDSEG(1:4,ISEG) = (/ VEC3(1), VEC3(2), VEC3(3), IG /)
         ENDIF
         
         CYCLE ! Next WSELEM
         
      ENDIF
      ! Intersection is line 2-3:
      IF ( (DOT2 == 0._EB) .AND. (DOT3 == 0._EB) ) THEN
         
         ! Second node:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD2); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! Third node:
         XYZ_INT2 = XYZV(IAXIS:KAXIS,NOD3); XYZ_INT2(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Set oriented segment regarding plane:
         IF ( DOT1 > 0._EB ) THEN
            SEG(NOD1:NOD2) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ELSE
            SEG(NOD1:NOD2) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ENDIF
         ! Find if oriented segment is in list:
         INLIST = .FALSE.
         DO ISEG=1,IBM_BODINT_PLANE%NSEGS
            ! IF ( ANY(IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) == SEG(NOD1)) .AND. &
            !      ANY(IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) == SEG(NOD2)) ) THEN
            !    INLIST = .TRUE.
            !    EXIT
            ! ENDIF
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == SEG(NOD1)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == SEG(NOD2)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == SEG(NOD2)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == SEG(NOD1)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (.NOT.INLIST) THEN
            ISEG = IBM_BODINT_PLANE%NSEGS + 1
            IBM_BODINT_PLANE%NSEGS = ISEG
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) = SEG
            EDGE_TRI = GEOMETRY(IG)%FACE_EDGES(EDG2,IWSEL) ! 2nd edge: Ed1 NOD1-NOD2, Ed2 NOD2-NOD3, Ed3 NOD3-NOD1.
            VEC3(1) = GEOMETRY(IG)%EDGE_FACES(1,EDGE_TRI)
            VEC3(2) = GEOMETRY(IG)%EDGE_FACES(2,EDGE_TRI)
            VEC3(3) = GEOMETRY(IG)%EDGE_FACES(4,EDGE_TRI)
            IBM_BODINT_PLANE%INDSEG(1:4,ISEG) = (/ VEC3(1), VEC3(2), VEC3(3), IG /)
         ENDIF
         
         CYCLE ! Next WSELEM
         
      ENDIF
      ! Intersection is line 3-1:
      IF ( (DOT3 == 0._EB) .AND. (DOT1 == 0._EB) ) THEN
         
         ! Third node:
         XYZ_INT1 = XYZV(IAXIS:KAXIS,NOD3); XYZ_INT1(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT1:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT1,IND_P(NOD1))
         
         ! First node:
         XYZ_INT2 = XYZV(IAXIS:KAXIS,NOD1); XYZ_INT2(X1AXIS) = X1PLN
         
         ! Index to XYZ_INT2:
         CALL GET_BODINT_NODE_INDEX(XYZ_INT2,IND_P(NOD2))
         
         ! Set oriented segment regarding plane:
         IF ( DOT2 > 0._EB ) THEN
            SEG(NOD1:NOD2) = (/ IND_P(NOD1), IND_P(NOD2) /)
         ELSE
            SEG(NOD1:NOD2) = (/ IND_P(NOD2), IND_P(NOD1) /)
         ENDIF
         ! Find if oriented segment is in list:
         INLIST = .FALSE.
         DO ISEG=1,IBM_BODINT_PLANE%NSEGS
            ! IF ( ANY(IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) == SEG(NOD1)) .AND. &
            !      ANY(IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) == SEG(NOD2)) ) THEN
            !    INLIST = .TRUE.
            !    EXIT
            ! ENDIF
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == SEG(NOD1)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == SEG(NOD2)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == SEG(NOD2)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == SEG(NOD1)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (.NOT.INLIST) THEN
            ISEG = IBM_BODINT_PLANE%NSEGS + 1
            IBM_BODINT_PLANE%NSEGS = ISEG
            IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG) = SEG
            EDGE_TRI = GEOMETRY(IG)%FACE_EDGES(EDG3,IWSEL) ! 3rd edge: Ed1 NOD1-NOD2, Ed2 NOD2-NOD3, Ed3 NOD3-NOD1.
            VEC3(1) = GEOMETRY(IG)%EDGE_FACES(1,EDGE_TRI)
            VEC3(2) = GEOMETRY(IG)%EDGE_FACES(2,EDGE_TRI)
            VEC3(3) = GEOMETRY(IG)%EDGE_FACES(4,EDGE_TRI)
            IBM_BODINT_PLANE%INDSEG(1:4,ISEG) = (/ VEC3(1), VEC3(2), VEC3(3), IG /)
         ENDIF
         
         CYCLE ! Next WSELEM
         
      ENDIF
            
      ! If you get to this point -> you have a problem:
      print*, "Error GET_BODINT_PLANE: Missed wet surface Triangle =",IWSEL
      
   ENDDO ! IWSEL
   
ENDDO MAIN_GEOM_LOOP


! Next step is to Test triangles sides normals on plane against the obtained 
! segments normals. If two identical segments found contain oposite
! normals, drop the segment in IBM_BODINT_PLANE%SEGS:
IF ( IBM_BODINT_PLANE%NTRIS > 0 ) THEN
   
   DO ITRI=1,IBM_BODINT_PLANE%NTRIS
      
      ! Triang conectivities:
      ELEM(NOD1:NOD3) = IBM_BODINT_PLANE%TRIS(NOD1:NOD3,ITRI)
      
      ! Coordinates in x2, x3 directions:
      X2X3(IAXIS,NOD1:NOD3) = (/ IBM_BODINT_PLANE%XYZ(X2AXIS,ELEM(NOD1)), &
                                 IBM_BODINT_PLANE%XYZ(X2AXIS,ELEM(NOD2)), &
                                 IBM_BODINT_PLANE%XYZ(X2AXIS,ELEM(NOD3)) /)
      X2X3(JAXIS,NOD1:NOD3) = (/ IBM_BODINT_PLANE%XYZ(X3AXIS,ELEM(NOD1)), &
                                 IBM_BODINT_PLANE%XYZ(X3AXIS,ELEM(NOD2)), &
                                 IBM_BODINT_PLANE%XYZ(X3AXIS,ELEM(NOD3)) /)
      
      ! Test Area sign, if -ve switch node order:
      AREALOC = 0.5_EB*(X2X3(IAXIS,NOD1)*X2X3(JAXIS,NOD2) - X2X3(IAXIS,NOD2)*X2X3(JAXIS,NOD1) + &
                        X2X3(IAXIS,NOD2)*X2X3(JAXIS,NOD3) - X2X3(IAXIS,NOD3)*X2X3(JAXIS,NOD2) + &
                        X2X3(IAXIS,NOD3)*X2X3(JAXIS,NOD1) - X2X3(IAXIS,NOD1)*X2X3(JAXIS,NOD3))
      IF (AREALOC < 0._EB) THEN
         ISEG    = ELEM(3)
         ELEM(3) = ELEM(2)
         ELEM(2)  =   ISEG
      ENDIF
      
      ! Now corresponding segments, ordered normal outside of plane x2-x3.
      EDGES(NOD1:NOD2,1) = (/ ELEM(1), ELEM(2) /) ! edge 1.
      EDGES(NOD1:NOD2,2) = (/ ELEM(2), ELEM(3) /) ! edge 2.
      EDGES(NOD1:NOD2,3) = (/ ELEM(3), ELEM(1) /)
      
      ! Now Test against segments, Beast approach:
      DO IEDGE=1,3
         DO ISEG=1,IBM_BODINT_PLANE%NSEGS
            IF ( (IBM_BODINT_PLANE%SEGS(NOD1,ISEG) == EDGES(NOD2,IEDGE)) .AND. &
                 (IBM_BODINT_PLANE%SEGS(NOD2,ISEG) == EDGES(NOD1,IEDGE)) ) THEN ! Edge normals
                                                                              ! oriented in opposite dirs.
               ! Set to SOLID SOLID segtype from BODINT_PLANE.SEGS
               IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG)=(/ IBM_SOLID, IBM_SOLID /)
               
            ENDIF
         ENDDO
      ENDDO
      
   ENDDO
ENDIF

! For segments that are related to 2 Wet Surface triangles, test if they are of type GG or SS:
DO ISEG=1,IBM_BODINT_PLANE%NSEGS
    IF (IBM_BODINT_PLANE%INDSEG(1,ISEG) > 1) THEN ! Related to 2 WS triangles:
       
       SEG(NOD1:NOD2) = IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG)
       
       ! Segment nodes positions:
       XP1(IAXIS:JAXIS) = IBM_BODINT_PLANE%XYZ( (/X2AXIS,X3AXIS/) ,SEG(NOD1))
       XP2(IAXIS:JAXIS) = IBM_BODINT_PLANE%XYZ( (/X2AXIS,X3AXIS/) ,SEG(NOD2))
       
       ! Unit normal versor along x2p (axis directed from NOD2 to NOD1):
       NMTX2P = SQRT( (XP1(IAXIS)-XP2(IAXIS))**2._EB + (XP1(JAXIS)-XP2(JAXIS))**2._EB )
       TX2P(IAXIS:JAXIS) = (XP1(IAXIS:JAXIS)-XP2(IAXIS:JAXIS)) * NMTX2P**(-1._EB)
       ! Versor along x3p.
       TX3P(IAXIS:JAXIS) = (/ -TX2P(JAXIS), TX2P(IAXIS) /)
       
       ! Now related WS triangles centroids:
       IWSEL1 = IBM_BODINT_PLANE%INDSEG(2,ISEG)
       IWSEL2 = IBM_BODINT_PLANE%INDSEG(3,ISEG)
       IG     = IBM_BODINT_PLANE%INDSEG(4,ISEG)
       
       ! Centroid of WS elem 1:
       ELEM1(NOD1:NOD3)  = GEOMETRY(IG)%FACES(NODS_WSEL*(IWSEL1-1)+1:NODS_WSEL*IWSEL1)
       XYZ1(IAXIS:KAXIS) = ( GEOMETRY(IG)%VERTS(MDIM*(ELEM1(NOD1)-1)+1:MDIM*ELEM1(NOD1)) + &
                             GEOMETRY(IG)%VERTS(MDIM*(ELEM1(NOD2)-1)+1:MDIM*ELEM1(NOD2)) + &
                             GEOMETRY(IG)%VERTS(MDIM*(ELEM1(NOD3)-1)+1:MDIM*ELEM1(NOD3)) ) / 3._EB
       NXYZ1(IAXIS:KAXIS)= GEOMETRY(IG)%FACES_NORMAL(IAXIS:KAXIS,IWSEL1)
       ! Normal versor in x3p-x1 direction:  
       NX3P1 = TX3P(IAXIS)*NXYZ1(X2AXIS) + TX3P(JAXIS)*NXYZ1(X3AXIS) 
       N1(IAXIS:JAXIS) = (/ NX3P1, NXYZ1(X1AXIS) /)
       NMNL = SQRT( N1(IAXIS)**2._EB + N1(JAXIS)**2._EB )
       N1 = N1 * NMNL**(-1._EB) 
       
       ! Centroid of WS elem 2:
       ELEM2(NOD1:NOD3)  = GEOMETRY(IG)%FACES(NODS_WSEL*(IWSEL2-1)+1:NODS_WSEL*IWSEL2)
       XYZ2(IAXIS:KAXIS) = ( GEOMETRY(IG)%VERTS(MDIM*(ELEM2(NOD1)-1)+1:MDIM*ELEM2(NOD1)) + &
                             GEOMETRY(IG)%VERTS(MDIM*(ELEM2(NOD2)-1)+1:MDIM*ELEM2(NOD2)) + &
                             GEOMETRY(IG)%VERTS(MDIM*(ELEM2(NOD3)-1)+1:MDIM*ELEM2(NOD3)) ) / 3._EB
       NXYZ2(IAXIS:KAXIS)= GEOMETRY(IG)%FACES_NORMAL(IAXIS:KAXIS,IWSEL2)
       ! Normal versor in x3p-x1 direction:  
       NX3P2 = TX3P(IAXIS)*NXYZ2(X2AXIS) + TX3P(JAXIS)*NXYZ2(X3AXIS) 
       N2(IAXIS:JAXIS) = (/ NX3P2, NXYZ2(X1AXIS) /)
       NMNL = SQRT( N2(IAXIS)**2._EB + N2(JAXIS)**2._EB )
       N2 = N2 * NMNL**(-1._EB)
       
       ! Define points in plane x3p-x1:
       ! vertex point:
       X3PVERT = TX3P(IAXIS)*XP1(IAXIS) + TX3P(JAXIS)*XP1(JAXIS)
       PVERT(IAXIS:JAXIS) = (/ X3PVERT, X1PLN /)
       ! First triangle centroid:
       X3P1 = TX3P(IAXIS)*XYZ1(X2AXIS) + TX3P(JAXIS)*XYZ1(X3AXIS)
       P1CEN(IAXIS:JAXIS) = (/ X3P1, XYZ1(X1AXIS) /)
       ! Second triangle centroid:
       X3P2 = TX3P(IAXIS)*XYZ2(X2AXIS) + TX3P(JAXIS)*XYZ2(X3AXIS)
       P2CEN(IAXIS:JAXIS) = (/ X3P2, XYZ2(X1AXIS) /)
       
       VCT(1:2) = 0
       PCT(IAXIS:JAXIS,1:2) = 0._EB
       
       ! Segment on triangle 1:
       V1(IAXIS:JAXIS) = P1CEN(IAXIS:JAXIS) - PVERT(IAXIS:JAXIS)
       CRSSNV = N1(IAXIS)*V1(JAXIS) - N1(JAXIS)*V1(IAXIS)
       IF (CRSSNV > 0._EB) THEN
           ! v1 stays as is, and is second segment:
           VEC(IAXIS:JAXIS,2) = V1(IAXIS:JAXIS)
           PCT(IAXIS:JAXIS,2) = P1CEN(IAXIS:JAXIS)
           VCT(2) = 1
       ELSE
           ! -v1 is the first segment:
           VEC(IAXIS:JAXIS,1) = -V1(IAXIS:JAXIS)
           PCT(IAXIS:JAXIS,1) = P1CEN(IAXIS:JAXIS)
           VCT(1) = 1
       ENDIF
       
       ! Segment on triangle 2:
       V2(IAXIS:JAXIS) = P2CEN(IAXIS:JAXIS) - PVERT(IAXIS:JAXIS)
       CRSSNV = N2(IAXIS)*V2(JAXIS) - N2(JAXIS)*V2(IAXIS)
       IF (CRSSNV > 0._EB) THEN
           ! v2 stays as is, and is second segment:
           VEC(IAXIS:JAXIS,2) = V2(IAXIS:JAXIS)
           PCT(IAXIS:JAXIS,2) = P2CEN(IAXIS:JAXIS)
           VCT(2) = 1
       ELSE
           ! -v2 is the first segment:
           VEC(IAXIS:JAXIS,1) = -V2(IAXIS:JAXIS)
           PCT(IAXIS:JAXIS,1) = P2CEN(IAXIS:JAXIS)
           VCT(1) = 1
       ENDIF
       
       IF ( (VCT(1) == 0) .OR. (VCT(2) == 0) ) THEN
          print*, "Error GET_BODINT_PLANE: One component of vct == 0."
       ENDIF
       
       ! Cross product of v1 and v2 gives magnitude along x2p axis:
       CTST = VEC(IAXIS,1)*VEC(JAXIS,2) - VEC(JAXIS,1)*VEC(IAXIS,2)
       
       ! Now tests:
       ! Start with SOLID GASPHASE  definition for segtype:
       IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG) = (/ IBM_SOLID, IBM_GASPHASE /)
       
       ! Test for SOLID SOLID condition:
       IF ( ((PCT(JAXIS,1)-X1PLN) > -GEOMEPS) .AND.  &
            ((PCT(JAXIS,2)-X1PLN) > -GEOMEPS) .AND. (CTST < GEOMEPS) ) THEN
           IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG) = (/ IBM_SOLID, IBM_SOLID /)
           CYCLE
       ELSEIF(((PCT(JAXIS,1)-X1PLN) < GEOMEPS) .AND. &
              ((PCT(JAXIS,2)-X1PLN) < GEOMEPS) .AND. (CTST < GEOMEPS) ) THEN
           IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG) = (/ IBM_SOLID, IBM_SOLID /)
           CYCLE
       ENDIF
       
       ! Test for GASPHASE GASPHASE condition:
       IF ( ((PCT(JAXIS,1)-X1PLN) > GEOMEPS) .AND.  &
            ((PCT(JAXIS,2)-X1PLN) > GEOMEPS) .AND. (CTST > GEOMEPS) ) THEN
            IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG) = (/ IBM_GASPHASE, IBM_GASPHASE /)
            CYCLE
       ELSEIF(((PCT(1,JAXIS)-X1PLN) < -GEOMEPS) .AND.  &
              ((PCT(2,JAXIS)-X1PLN) < -GEOMEPS) .AND. (CTST > GEOMEPS) ) THEN
            IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG) = (/ IBM_GASPHASE, IBM_GASPHASE /)
            CYCLE
       ENDIF
       
    ENDIF
ENDDO


! For the time being, as IBM_BODINT_PLANE is used to create Cartesian face cut-faces
! We eliminate from the list the SEGTYPE=[SOLID SOLID] segments:
ALLOCATE(SEGAUX(NOD1:NOD2,IBM_BODINT_PLANE%NSEGS))
ALLOCATE(INDSEGAUX(IBM_MAX_WSTRIANG_SEG+2,IBM_BODINT_PLANE%NSEGS))
ALLOCATE(SEGTYPEAUX(NOD1:NOD2,IBM_BODINT_PLANE%NSEGS))

!print*, "IBM_BODINT_PLANE%NSEGS=",IBM_BODINT_PLANE%NSEGS

ISEG_NEW = 0
DO ISEG=1,IBM_BODINT_PLANE%NSEGS
    IF( (IBM_BODINT_PLANE%SEGTYPE(NOD1,ISEG) == IBM_SOLID) .AND. &
        (IBM_BODINT_PLANE%SEGTYPE(NOD2,ISEG) == IBM_SOLID) ) CYCLE
       
       ISEG_NEW = ISEG_NEW + 1
       SEGAUX(NOD1:NOD2,ISEG_NEW) = IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG)
       INDSEGAUX(1:IBM_MAX_WSTRIANG_SEG+2,ISEG_NEW) = &
          IBM_BODINT_PLANE%INDSEG(1:IBM_MAX_WSTRIANG_SEG+2,ISEG)
       SEGTYPEAUX(NOD1:NOD2,ISEG_NEW) = IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,ISEG)
ENDDO
IBM_BODINT_PLANE%NSEGS = ISEG_NEW
IBM_BODINT_PLANE%SEGS(NOD1:NOD2,1:ISEG_NEW) = SEGAUX(NOD1:NOD2,1:ISEG_NEW)
IBM_BODINT_PLANE%INDSEG(1:IBM_MAX_WSTRIANG_SEG+2,1:ISEG_NEW) = &
    INDSEGAUX(1:IBM_MAX_WSTRIANG_SEG+2,1:ISEG_NEW)
IBM_BODINT_PLANE%SEGTYPE(NOD1:NOD2,1:ISEG_NEW) = SEGTYPEAUX(NOD1:NOD2,1:ISEG_NEW)

DEALLOCATE(SEGAUX,INDSEGAUX,SEGTYPEAUX)


! Segments Crossings fields: 
! Initialize nbcross with segment nodes locations:
IBM_BODINT_PLANE%NBCROSS(1:IBM_BODINT_PLANE%NSEGS)                   =  0._EB
IBM_BODINT_PLANE%SVAR(1:IBM_MAX_NBCROSS,1:IBM_BODINT_PLANE%NSEGS)    = -1._EB

! Add segment ends as crossings:
DO ISEG=1,IBM_BODINT_PLANE%NSEGS
   
   ! End nodes to cross:
   SEG(NOD1:NOD2) = IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG)
   XYZ1(IAXIS:KAXIS) = IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,SEG(NOD1))
   XYZ2(IAXIS:KAXIS) = IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,SEG(NOD2))
   
   ! x2_x3 of segment point 1:
   X2_1 = XYZ1(X2AXIS); X3_1 = XYZ1(X3AXIS)
   ! x2_x3 of segment point 2:
   X2_2 = XYZ2(X2AXIS); X3_2 = XYZ2(X3AXIS)
   
   ! Segment length:
   SLEN = SQRT( (X2_2-X2_1)**2._EB + (X3_2-X3_1)**2._EB )
   
   ! First node:
   SBOD = 0._EB
   ! Add crossing to BODINT_PLANE:
   NBCROSS = IBM_BODINT_PLANE%NBCROSS(ISEG) + 1
   IBM_BODINT_PLANE%NBCROSS(ISEG) = NBCROSS
   IBM_BODINT_PLANE%SVAR(NBCROSS,ISEG) = SBOD
   
   ! Second node:
   SBOD = SLEN
   ! Add crossing to BODINT_PLANE:
   NBCROSS = IBM_BODINT_PLANE%NBCROSS(ISEG) + 1
   IBM_BODINT_PLANE%NBCROSS(ISEG) = NBCROSS
   IBM_BODINT_PLANE%SVAR(ISEG,NBCROSS) = SBOD
 
ENDDO

! Write out:
! print*, "Up to END of GET_BODINT_PLANE=",X1AXIS,X1PLN
! print*, "NNODS=",IBM_BODINT_PLANE%NNODS
! DO INOD=1,IBM_BODINT_PLANE%NNODS
!    write(*,'(I3,A,3F16.12)') INOD,", ",IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,INOD)
! END DO
! print*, "NSEGS=",IBM_BODINT_PLANE%NSEGS
! DO ISEG=1,IBM_BODINT_PLANE%NSEGS
!    print*, " ",ISEG,IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG)
! END DO
! print*, "NSGLS=",IBM_BODINT_PLANE%NSGLS
! DO ISGL=1,IBM_BODINT_PLANE%NSGLS
!    print*, " ",ISGL,IBM_BODINT_PLANE%SGLS(NOD1,ISGL)
! END DO
! print*, "NTRIS=",IBM_BODINT_PLANE%NTRIS
! pause



RETURN
END SUBROUTINE GET_BODINT_PLANE



! -------------------------- GET_X2INTERSECTIONS --------------------------------

SUBROUTINE GET_X2INTERSECTIONS(X1AXIS,X2AXIS,X3AXIS,X3RAY)

IMPLICIT NONE
INTEGER, INTENT(IN) :: X1AXIS, X2AXIS, X3AXIS
REAL(EB),INTENT(IN) :: X3RAY

! Local Variables:
INTEGER :: ISGL, SGL, ISEG, SEG(NOD1:NOD2)
REAL(EB):: XYZ1(MDIM), XYZ2(MDIM), X2_1, X2_2, X3_1, X3_2, DOT1, DOT2
REAL(EB):: SVARI, STANI(IAXIS:JAXIS)
INTEGER :: ICRSI(LOW:HIGH), SCRSI, ISSEG(LOW:HIGH), GAM(LOW:HIGH)
REAL(EB):: X3MIN, X3MAX, DV12(MDIM), MODTI, NOMLI(IAXIS:JAXIS)
LOGICAL :: OUTRAY

INTEGER :: IBM_N_CRS_AUX
REAL(EB):: IBM_SVAR_CRS_AUX(IBM_MAXCROSS_X2)
!INTEGER :: IBM_IS_CRS_AUX(IBM_MAXCROSS_X2)
INTEGER :: IBM_IS_CRS2_AUX(LOW:HIGH,IBM_MAXCROSS_X2)
REAL(EB):: IBM_SEG_TAN_AUX(IAXIS:JAXIS,IBM_MAXCROSS_X2)
INTEGER :: IBM_SEG_CRS_AUX(IBM_MAXCROSS_X2)
INTEGER :: CRS_NUM(IBM_MAXCROSS_X2),IND_CRS(LOW:HIGH,IBM_MAXCROSS_X2)
INTEGER :: LEFT_MEDIA, NCRS_REMAIN
INTEGER :: ICRS, IDCR, IND_LEFT, IND_RIGHT
LOGICAL :: DROP_SS_GG, FOUND_LEFT, NOT_COUNTED(IBM_MAXCROSS_X2)

! Initialize crossings arrays:
IBM_N_CRS = 0
IBM_SVAR_CRS = 1._EB / GEOMEPS
IBM_IS_CRS   = IBM_UNDEFINED
IBM_IS_CRS2  = IBM_UNDEFINED
IBM_SEG_TAN  = 0._EB
IBM_SEG_CRS  = 0

! First Single points:
! Treat them as [GASPHASE GASPHASE] crossings:
DO ISGL=1,IBM_BODINT_PLANE%NSGLS
   
   SGL = IBM_BODINT_PLANE%SGLS(NOD1,ISGL)
   XYZ1(IAXIS:KAXIS) = IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,SGL)
   
   ! x2-x3 coordinates of point:
   X2_1 = XYZ1(X2AXIS)
   X3_1 = XYZ1(X3AXIS)
   
   ! Dot product dot(X_1-XRAY,e3)
   DOT1 = X3_1-X3RAY
   IF(ABS(DOT1) <= GEOMEPS) DOT1=0._EB
   
   IF( ABS(DOT1) == 0._EB ) THEN
       ! Point 1:
       SVARI = X2_1
       ICRSI(LOW:HIGH) = IBM_GASPHASE
       SCRSI = -ISGL
       STANI(IAXIS:JAXIS)  = 0._EB
       
       ! Insertion sort:
       CALL INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI) ! Modifies crossings arrays.
       
   ENDIF
   
ENDDO

! Now Segments:
SEGMENTS_LOOP : DO ISEG=1,IBM_BODINT_PLANE%NSEGS
   
   SEG(NOD1:NOD2)    = IBM_BODINT_PLANE%SEGS(NOD1:NOD2,ISEG)
   XYZ1(IAXIS:KAXIS) = IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,SEG(NOD1))
   XYZ2(IAXIS:KAXIS) = IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,SEG(NOD2))
   
   ! x2,x3 coordinates of segment:
   X2_1 = XYZ1(X2AXIS)
   X3_1 = XYZ1(X3AXIS) ! Lower index endpoint.
   X2_2 = XYZ2(X2AXIS)
   X3_2 = XYZ2(X3AXIS) ! Upper index endpoint.
   
   ! Is segment aligned with x3 direction?
   IBM_BODINT_PLANE%X3ALIGNED(ISEG) = (ABS(X2_2-X2_1) < GEOMEPS)
   ! Is segment aligned with x2 rays?:
   IBM_BODINT_PLANE%X2ALIGNED(ISEG) = (ABS(X3_2-X3_1) < GEOMEPS)
   
   ! First Test if the whole segment is on one side of the Ray:
   ! Test segment crosses the ray, or is in geomepsilon proximity
   ! of it:
   X3MIN = MIN(X3_1,X3_2)
   X3MAX = MAX(X3_1,X3_2)
   OUTRAY=(((X3RAY-X3MAX) > GEOMEPS) .OR. ((X3MIN-X3RAY) > GEOMEPS))
   
   IF (OUTRAY) CYCLE
   
   DOT1 = X3_1-X3RAY
   DOT2 = X3_2-X3RAY
   
   IF(ABS(DOT1) <= GEOMEPS) DOT1 = 0._EB
   IF(ABS(DOT2) <= GEOMEPS) DOT2 = 0._EB
   
   ! Segment tangent unit vector.
   DV12(IAXIS:JAXIS) = XYZ2( (/ X2AXIS, X3AXIS /) ) - XYZ1( (/ X2AXIS, X3AXIS /) )
   MODTI = SQRT( DV12(IAXIS)**2._EB + DV12(JAXIS)**2._EB )
   STANI(IAXIS:JAXIS)  = DV12(IAXIS:JAXIS) * MODTI**(-1._EB)
   NOMLI(IAXIS:JAXIS)  = (/ STANI(JAXIS), -STANI(IAXIS) /)
   ISSEG(LOW:HIGH) = IBM_BODINT_PLANE%SEGTYPE(LOW:HIGH,ISEG)
   
   ! For x2, in local x2-x3 coords e2=(1,0):
   GAM(LOW) = (1 + NINT(SIGN( 1._EB, NOMLI(IAXIS))) ) / 2  !(1+SIGN(DOT_PRODUCT(NOMLI,e2)))/2;
   GAM(HIGH)= (1 - NINT(SIGN( 1._EB, NOMLI(IAXIS))) ) / 2  !(1-SIGN(DOT_PRODUCT(NOMLI,e2)))/2;
   
   ! Test if whole segment is in ray, if so add segment nodes as crossings:
   IF( (ABS(DOT1)+ABS(DOT2)) == 0._EB ) THEN
      
      ! Count both points as crossings:
      ! Point 1:
      SVARI = MIN(X2_1,X2_2)
      ICRSI(LOW:HIGH) = (/ IBM_GASPHASE, IBM_SOLID /)
      SCRSI = ISEG
      
      ! Insertion sort:
      CALL INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI)
      
      ! Point 2:
      SVARI = MAX(X2_1,X2_2)
      ICRSI(LOW:HIGH) = (/ IBM_SOLID, IBM_GASPHASE /)
      SCRSI = ISEG
      
      ! Insertion sort:
      CALL INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI)
         
      CYCLE
      
   ENDIF
   
   ! Now nodes individually:
   IF( ABS(DOT1) == 0._EB ) THEN
      
      ! Point 1:
      SVARI = X2_1
      
      ! LOW and HIGH media type, using the segment definition:
      ICRSI(LOW) = GAM(LOW)*ISSEG(LOW) + GAM(HIGH)*ISSEG(HIGH)
      ICRSI(HIGH)= GAM(LOW)*ISSEG(HIGH)+ GAM(HIGH)*ISSEG(LOW)
      
      SCRSI = ISEG
      
      ! Insertion sort:
      CALL INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI)
      
      CYCLE
      
   ENDIF
   IF( ABS(DOT2) == 0._EB ) THEN
      
      ! Point 2:
      SVARI = X2_2
      
      ! LOW and HIGH media type, using the segment definition:
      ICRSI(LOW) = GAM(LOW)*ISSEG(LOW) + GAM(HIGH)*ISSEG(HIGH)
      ICRSI(HIGH)= GAM(LOW)*ISSEG(HIGH)+ GAM(HIGH)*ISSEG(LOW)
      SCRSI = ISEG
      
      ! Insertion sort:
      CALL INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI)
      
      CYCLE
      
   ENDIF
   
   ! Finally regular case:
   ! Points 1 on one side of ray, point 2 on the other:
   ! IF ((DOT1 > 0. .AND. DOT2 < 0.) .OR. (DOT1 < 0. .AND. DOT2 > 0.))
   IF( DOT1*DOT2 < 0._EB ) THEN
      
      ! Intersection Point along segment:
      !DS    = (X3RAY-X3_1) / (X3_2-X3_1)
      !SVARI = X2_1 + DS*(X2_2-X2_1)
      SVARI = X2_1 + (X3RAY-X3_1) * (X2_2-X2_1) / (X3_2-X3_1)
      
      ! LOW and HIGH media type, using the segment definition:
      ICRSI(LOW) = GAM(LOW)*ISSEG(LOW) + GAM(HIGH)*ISSEG(HIGH)
      ICRSI(HIGH)= GAM(LOW)*ISSEG(HIGH)+ GAM(HIGH)*ISSEG(LOW)
      SCRSI = ISEG
      
      ! Insertion sort:
      CALL INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI)
      
      CYCLE
      
   ENDIF
   
   print*, "Error GET_X2INTERSECTIONS: Missed segment=",ISEG
   
ENDDO SEGMENTS_LOOP

! Do we have any intersections?
IF( IBM_N_CRS == 0 ) RETURN

! Once all intersections and corresponding tags have been found, there 
! might be points that lay on the same x2 location. Intersections type 
! GG are dropped when other types are present at the same s. The remaining 
! are reordered such that media continuity is preserved as the ray is 
! covered for increasing s, by looking at the high side type of the 
! adjacent intersection point to the left (if the intersection is the one
! with lowest s, the media to the left is type IBM_GASPHASE). Points of same 
! type are collapsed. The final unique intersection type is obtained by 
! using the LOW type of the first intersection and the HIGH type of the 
! last intersection found at a given s. 

IBM_N_CRS_AUX    = 0
IBM_SVAR_CRS_AUX = 1._EB/GEOMEPS ! svar = x2_intersection
IBM_IS_CRS2_AUX  = IBM_UNDEFINED ! Is the intersection an actual GS.
IBM_SEG_CRS_AUX  = 0             ! Segment containing the crossing.
IBM_SEG_TAN_AUX  = 0._EB         ! Segment orientation for each intersection.

! Count how many crossings with different SVAR:
CRS_NUM      = 0
ICRS         = 1
CRS_NUM(ICRS)= 1
IND_CRS      = 0
IND_CRS(LOW, CRS_NUM(ICRS)) = ICRS-1
IND_CRS(HIGH,CRS_NUM(ICRS)) = IND_CRS(HIGH,ICRS)+1

DO ICRS=2,IBM_N_CRS
   IF( ABS(IBM_SVAR_CRS(ICRS)-IBM_SVAR_CRS(ICRS-1)) < GEOMEPS ) THEN
      CRS_NUM(ICRS) = CRS_NUM(ICRS-1)
   ELSE
      CRS_NUM(ICRS) = CRS_NUM(ICRS-1)+1
      IND_CRS(LOW,CRS_NUM(ICRS)) = ICRS-1
   ENDIF
   IND_CRS(HIGH,CRS_NUM(ICRS)) = IND_CRS(HIGH,CRS_NUM(ICRS))+1
ENDDO

! This is where we merge intersections at same svar location (i.e. same CRS_NUM value):
! Loop over different crossings:
LEFT_MEDIA = IBM_GASPHASE
DO IDCR=1,CRS_NUM(IBM_N_CRS)
   
   IBM_N_CRS_AUX = IBM_N_CRS_AUX + 1
   ! Case of single crossing with new svar:
   IF( IND_CRS(HIGH,IDCR) == 1 ) THEN
      
      ICRS =IND_CRS(LOW,IDCR) + 1
      
      IF( IBM_IS_CRS2(LOW,ICRS) /= LEFT_MEDIA ) THEN
         print*, "Error GET_X2INTERSECTIONS: IS_CRS(LOW,ICRS) ~= LEFT_MEDIA, media continuity problem"
      ENDIF
      
      IBM_SVAR_CRS_AUX(IBM_N_CRS_AUX)             = IBM_SVAR_CRS(ICRS)
      IBM_IS_CRS2_AUX(LOW:HIGH,IBM_N_CRS_AUX)     = IBM_IS_CRS2(LOW:HIGH,ICRS)
      IBM_SEG_CRS_AUX(IBM_N_CRS_AUX)              = IBM_SEG_CRS(ICRS)
      IBM_SEG_TAN_AUX(IAXIS:JAXIS,IBM_N_CRS_AUX)  = IBM_SEG_TAN(IAXIS:JAXIS,ICRS)
      LEFT_MEDIA = IBM_IS_CRS2(HIGH,ICRS)
      
      CYCLE
      
   ENDIF
   
   ! Case of several crossings with new svar:
   DROP_SS_GG = .FALSE.
   DO ICRS=IND_CRS(LOW,IDCR)+1,IND_CRS(LOW,IDCR)+IND_CRS(HIGH,IDCR)
      IF( IBM_IS_CRS2(LOW,ICRS) /= IBM_IS_CRS2(HIGH,ICRS) ) THEN
         DROP_SS_GG = .TRUE.
         EXIT
      ENDIF
   ENDDO
   
   ! Variables related to new svar crossing:
   ICRS = IND_CRS(LOW,IDCR) + 1
   IBM_SVAR_CRS_AUX(IBM_N_CRS_AUX)             = IBM_SVAR_CRS(ICRS)
   IBM_SEG_CRS_AUX(IBM_N_CRS_AUX)              = IBM_SEG_CRS(ICRS)
   IBM_SEG_TAN_AUX(IAXIS:JAXIS,IBM_N_CRS_AUX)  = IBM_SEG_TAN(IAXIS:JAXIS,ICRS)
   
   ! Now figure out the type of crossing:
   NOT_COUNTED = .TRUE.
   NCRS_REMAIN = IND_CRS(HIGH,IDCR)
   IF(DROP_SS_GG) THEN
      
      ! Left Side:
      FOUND_LEFT = .FALSE.
      IND_LEFT   = 0
      IND_RIGHT  = 0
      
      DO ICRS=IND_CRS(LOW,IDCR)+1,IND_CRS(LOW,IDCR)+IND_CRS(HIGH,IDCR)
         ! Case crossing type GG or SS, drop:
         IF (IBM_IS_CRS2(LOW,ICRS) == IBM_IS_CRS2(HIGH,ICRS)) CYCLE
         IND_LEFT  =  IND_LEFT + IBM_IS_CRS2(LOW,ICRS)
         IND_RIGHT = IND_RIGHT + IBM_IS_CRS2(HIGH,ICRS)
      ENDDO
      
      if (IND_LEFT  /= 0) IND_LEFT = SIGN(1,IND_LEFT)
      if (IND_RIGHT /= 0) IND_RIGHT = SIGN(1,IND_RIGHT)
      
      IF (ABS(IND_LEFT)+ABS(IND_RIGHT) == 0) THEN ! Same number of SG and GS crossings, 
                                                  ! both sides of the crossing
                                                  ! defined as left_media:
         IBM_IS_CRS2_AUX(LOW:HIGH,IBM_N_CRS_AUX)     = LEFT_MEDIA
      ELSEIF(IND_LEFT == LEFT_MEDIA) THEN
         IBM_IS_CRS2_AUX(LOW:HIGH,IBM_N_CRS_AUX) = (/ IND_LEFT, IND_RIGHT /) ! GS or SG.
      ELSE
         print*, "Error GET_X2INTERSECTIONS: DROP_SS_GG = .TRUE., Didn't find left side continuity."
         print*, "IBM_N_CRS=",IBM_N_CRS,", IDCR=",IDCR
         print*, ICRS,"IND_LEFT=",IND_LEFT,", IND_RIGHT=",IND_RIGHT
         print*, "IBM_IS_CRS2(LOW:HIGH,ICRS)",IBM_IS_CRS2(LOW:HIGH,ICRS)
      ENDIF
      LEFT_MEDIA = IBM_IS_CRS2_AUX(HIGH,IBM_N_CRS_AUX)
      
   ELSE ! Intersections are either GG or SS
      
      ! Left side:
      FOUND_LEFT = .FALSE.
      DO ICRS=IND_CRS(LOW,IDCR)+1,IND_CRS(LOW,IDCR)+IND_CRS(HIGH,IDCR)
         
         ! Case GG or SS with IBM_IS_CRS2(LOW,ICRS) == LEFT_MEDIA:
         ! This collapses all types SS or GG that have the left side
         ! type. Note they should all be one type (either GG or SS):
         IF (IBM_IS_CRS2(LOW,ICRS) == LEFT_MEDIA) THEN
            IBM_IS_CRS2_AUX(LOW:HIGH,IBM_N_CRS_AUX) = IBM_IS_CRS2(LOW:HIGH,ICRS)
            NOT_COUNTED(ICRS) = .FALSE.
            NCRS_REMAIN = NCRS_REMAIN-1
            FOUND_LEFT = .TRUE.
         ENDIF
      ENDDO
      
      IF(.NOT.FOUND_LEFT) print*, "Error GET_X2INTERSECTIONS: DROP_SS_GG = .FALSE., Didn't find left side continuity."
      
      IF ( NCRS_REMAIN /= 0) print*, "Error GET_X2INTERSECTIONS: DROP_SS_GG = .FALSE., NCRS_REMAIN /= 0."
      
      LEFT_MEDIA = IBM_IS_CRS2_AUX(HIGH,IBM_N_CRS_AUX)
      
   ENDIF
   
ENDDO

! Copy final results:
IBM_N_CRS    = IBM_N_CRS_AUX
IBM_SVAR_CRS(1:IBM_MAXCROSS_X2)             = IBM_SVAR_CRS_AUX(1:IBM_MAXCROSS_X2)
IBM_SEG_CRS(1:IBM_MAXCROSS_X2)              = IBM_SEG_CRS_AUX(1:IBM_MAXCROSS_X2)
IBM_SEG_TAN(IAXIS:JAXIS,1:IBM_MAXCROSS_X2)  = IBM_SEG_TAN_AUX(IAXIS:JAXIS,1:IBM_MAXCROSS_X2)
! IBM_IS_CRS2(LOW:HIGH,1:IBM_MAXCROSS_X2) = IBM_IS_CRS2_AUX(LOW:HIGH,1:IBM_MAXCROSS_X2)

DO ICRS=1,IBM_N_CRS
  IBM_IS_CRS(ICRS) = 2*( IBM_IS_CRS2_AUX(LOW,ICRS) + 1 ) - IBM_IS_CRS2_AUX(HIGH,ICRS)
ENDDO


! Write out:
! print*, "X3RAY=",X3RAY,", Intersect X2=",IBM_N_CRS
! DO ICRS=1,IBM_N_CRS
!    print*, ICRS,", ",IBM_SVAR_CRS(ICRS),", ",IBM_IS_CRS(ICRS)
! ENDDO

RETURN
END SUBROUTINE GET_X2INTERSECTIONS


! ------------------------- INSERT_RAY_CROSS ------------------------------------

SUBROUTINE INSERT_RAY_CROSS(SVARI,ICRSI,SCRSI,STANI)

REAL(EB), INTENT(IN) :: SVARI, STANI(IAXIS:JAXIS)
INTEGER,  INTENT(IN) :: ICRSI(LOW:HIGH), SCRSI

! Local Variables:
INTEGER :: ICRS, IDUM

IBM_N_CRS = IBM_N_CRS + 1

! Test maximum crossings defined:
! IF ( IBM_N_CRS > IBM_MAXCROSS_X2) THEN
!    print*, "Error INSERT_RAY_CROSS: IBM_N_CRS > IBM_MAXCROSS_X2."
! ENDIF

! Add in place, ascending value order:
DO ICRS=1,IBM_N_CRS ! The updated IBM_N_CRS is for ICRS to reach the 
                    ! initialization value IBM_SVAR_CRS(ICRS)=1/GEOMEPS.
   IF( SVARI < IBM_SVAR_CRS(ICRS) ) EXIT
ENDDO

! Here copy from the back (updated IBM_N_CRS) to the ICRS location:
! if ICRS=IBM_N_CRS -> nothing gets copied:
DO IDUM = IBM_N_CRS,ICRS+1,-1
   IBM_SVAR_CRS(IDUM)           = IBM_SVAR_CRS(IDUM-1)
   IBM_IS_CRS2(LOW:HIGH,IDUM)   = IBM_IS_CRS2(LOW:HIGH,IDUM-1)
   IBM_SEG_CRS(IDUM)            = IBM_SEG_CRS(IDUM-1);
   IBM_SEG_TAN(IAXIS:JAXIS,IDUM)= IBM_SEG_TAN(IAXIS:JAXIS,IDUM-1); 
ENDDO

IBM_SVAR_CRS(ICRS)             = SVARI              ! x2 location.
IBM_IS_CRS2(LOW:HIGH,ICRS)     = ICRSI(LOW:HIGH)    ! Does point separate GASPHASE from SOLID?
IBM_SEG_CRS(ICRS)              = SCRSI              ! Segment on BOINT_PLANE the crossing belongs to.
IBM_SEG_TAN(IAXIS:JAXIS,ICRS)  = STANI(IAXIS:JAXIS) ! IBM_SEG_TAN might not be needed in new implementation.

RETURN
END SUBROUTINE INSERT_RAY_CROSS

! ---------------------- GET_BODINT_NODE_INDEX ----------------------------------

SUBROUTINE GET_BODINT_NODE_INDEX(XYZ,IND_PI)

REAL(EB), INTENT(IN)  :: XYZ(MDIM)
INTEGER,  INTENT(OUT) :: IND_PI

! Local variables:
!LOGICAL :: INLIST
INTEGER :: INOD
REAL(EB):: NORMPT

! Test if XYZ is already on IBM_BODINT_PLANE%XYZ:
! INLIST = .FALSE.
IND_PI = -1 ! Initialize to negative index.
DO INOD=1,IBM_BODINT_PLANE%NNODS
   ! Take distance norm:
   NORMPT = SQRT( (IBM_BODINT_PLANE%XYZ(IAXIS,INOD)-XYZ(IAXIS))**2._EB + &
                  (IBM_BODINT_PLANE%XYZ(JAXIS,INOD)-XYZ(JAXIS))**2._EB + &
                  (IBM_BODINT_PLANE%XYZ(KAXIS,INOD)-XYZ(KAXIS))**2._EB )
   IF (NORMPT < GEOMEPS) THEN
      IND_PI = INOD
      ! INLIST = .TRUE.
      RETURN
   ENDIF
ENDDO

!IF (.NOT. INLIST)
   IND_PI = IBM_BODINT_PLANE%NNODS + 1
   IBM_BODINT_PLANE%NNODS = IND_PI
   IBM_BODINT_PLANE%XYZ(IAXIS:KAXIS,IND_PI) = XYZ
!ENDIF

RETURN
END SUBROUTINE GET_BODINT_NODE_INDEX


! -------------------- LINE_INTERSECT_COORDPLANE --------------------------------

SUBROUTINE LINE_INTERSECT_COORDPLANE(X1AXIS,X1PLN,PLNORMAL,LNC,XYZ_INT,INTFLG)

INTEGER, INTENT(IN)  :: X1AXIS
REAL(EB), INTENT(IN) :: X1PLN,PLNORMAL(MDIM),LNC(MDIM,NOD1:NOD2)
REAL(EB), INTENT(OUT):: XYZ_INT(MDIM)
LOGICAL, INTENT(OUT) :: INTFLG

! Local variables:
REAL(EB) :: DVEC(MDIM), DIRV(MDIM), NMDV, DENOM, PLNEQ, TLINE

! Initialize:
INTFLG = .FALSE.
XYZ_INT(IAXIS:KAXIS) = 0._EB 

! Preliminary calculations:
DVEC(IAXIS:KAXIS) = LNC(IAXIS:KAXIS,NOD2) - LNC(IAXIS:KAXIS,NOD1)
NMDV = SQRT( DVEC(IAXIS)**2._EB + DVEC(JAXIS)**2._EB + DVEC(KAXIS)**2._EB )
DIRV = DVEC(IAXIS:KAXIS) * NMDV**(-1._EB)
DENOM = DIRV(IAXIS)*PLNORMAL(IAXIS) +DIRV(JAXIS)*PLNORMAL(JAXIS) +DIRV(KAXIS)*PLNORMAL(KAXIS) 
PLNEQ = LNC(IAXIS,NOD1)*PLNORMAL(IAXIS) + &
        LNC(JAXIS,NOD1)*PLNORMAL(JAXIS) + &
        LNC(KAXIS,NOD1)*PLNORMAL(KAXIS) - X1PLN
        
! Line parallel to plane:
IF ( ABS(DENOM) < GEOMEPS ) THEN
   ! Check if seg lies on plane or not.
   ! Do this by checking if node one of segment is on plane.
   IF ( ABS(PLNEQ) < GEOMEPS ) THEN
      XYZ_INT(IAXIS:KAXIS) = LNC(IAXIS:KAXIS,NOD1); XYZ_INT(X1AXIS) = X1PLN
      INTFLG = .TRUE.
   ENDIF
   RETURN
ENDIF

! Non parallel case:
TLINE = -PLNEQ/DENOM  ! Coordinate along the line LNC.
XYZ_INT(IAXIS:KAXIS) = LNC(IAXIS:KAXIS,NOD1) + TLINE*DIRV(IAXIS:KAXIS) ! Intersection point.
XYZ_INT(X1AXIS) = X1PLN ! Force X1AXIS coordinate to be the planes value.
INTFLG = .TRUE.

RETURN
END SUBROUTINE LINE_INTERSECT_COORDPLANE


! ------------------------- IBM_INIT_GEOM ---------------------------------------

SUBROUTINE IBM_INIT_GEOM

! Local Variables:
INTEGER :: IG, IWSEL, INOD, IEDGE, NWSEL, NWSEDG, IEDLIST
INTEGER :: WSELEM(NOD1:NOD3),SEG(NOD1:NOD2)
REAL(EB):: XYZV(MDIM,NODS_WSEL), V12(MDIM), V23(MDIM), WSNORM(MDIM)
REAL(EB):: MGNRM, XCEN
LOGICAL :: INLIST

! Geometry loop:
GEOMETRY_LOOP : DO IG=1,N_GEOMETRY
   
   NWSEL = GEOMETRY(IG)%N_FACES
   
   ! Allocate fields of Geometry used by IBM:
   ! WS Faces normal unit vectors:
   IF (ALLOCATED(GEOMETRY(IG)%FACES_NORMAL)) DEALLOCATE(GEOMETRY(IG)%FACES_NORMAL)
   ALLOCATE(GEOMETRY(IG)%FACES_NORMAL(MDIM,NWSEL))
   ! WS Faces areas:
   IF (ALLOCATED(GEOMETRY(IG)%FACES_AREA)) DEALLOCATE(GEOMETRY(IG)%FACES_AREA)
   ALLOCATE(GEOMETRY(IG)%FACES_AREA(NWSEL))
   ! WS Faces edges:
   IF (ALLOCATED(GEOMETRY(IG)%EDGES)) DEALLOCATE(GEOMETRY(IG)%EDGES)
   ALLOCATE(GEOMETRY(IG)%EDGES(NOD1:NOD2,3*NWSEL)) ! Size large enough to take care of surfaces
                                         ! (zero thickness immersed solids) and 3D domains
                                         ! boundaries (what we call wet surfaces).
   ! WS Faces edges:
   IF (ALLOCATED(GEOMETRY(IG)%FACE_EDGES)) DEALLOCATE(GEOMETRY(IG)%FACE_EDGES)
   ALLOCATE(GEOMETRY(IG)%FACE_EDGES(EDG1:EDG3,NWSEL)) ! Edges in GEOMETRY(IG)%EDGES for this triangle.
   ! WS Edges faces:
   IF (ALLOCATED(GEOMETRY(IG)%EDGE_FACES)) DEALLOCATE(GEOMETRY(IG)%EDGE_FACES)
   ALLOCATE(GEOMETRY(IG)%EDGE_FACES(5,3*NWSEL)) ! Triangles sharing this edge [niel iwel1 LocEdge1 iwel2 LocEdge2]
   
   GEOMETRY(IG)%GEOM_VOLUME = 0._EB
   GEOMETRY(IG)%GEOM_AREA   = 0._EB
   
   ! Compute normal, area and volume:
   DO IWSEL=1,NWSEL
      
      WSELEM(NOD1:NOD3) = GEOMETRY(IG)%FACES(NODS_WSEL*(IWSEL-1)+1:NODS_WSEL*IWSEL)
      
      ! Triangles NODES coordinates:
      DO INOD=NOD1,NOD3
         XYZV(IAXIS:KAXIS,INOD) = GEOMETRY(IG)%VERTS(MDIM*(WSELEM(INOD)-1)+1:MDIM*WSELEM(INOD))
      ENDDO
      
      V12(IAXIS:KAXIS) = XYZV(IAXIS:KAXIS,NOD2) - XYZV(IAXIS:KAXIS,NOD1)
      V23(IAXIS:KAXIS) = XYZV(IAXIS:KAXIS,NOD3) - XYZV(IAXIS:KAXIS,NOD2)
      
      ! Cross V12 x V23:
      WSNORM(IAXIS) = V12(JAXIS)*V23(KAXIS) - V12(KAXIS)*V23(JAXIS)
      WSNORM(JAXIS) = V12(KAXIS)*V23(IAXIS) - V12(IAXIS)*V23(KAXIS)
      WSNORM(KAXIS) = V12(IAXIS)*V23(JAXIS) - V12(JAXIS)*V23(IAXIS)
      
      MGNRM = SQRT( WSNORM(IAXIS)**2._EB + WSNORM(JAXIS)**2._EB + WSNORM(KAXIS)**2._EB )
      
      XCEN  = (XYZV(IAXIS,NOD1) + XYZV(IAXIS,NOD2) + XYZV(IAXIS,NOD3)) / 3._EB
      
      ! Assign to GEOMETRY:
      GEOMETRY(IG)%FACES_NORMAL(IAXIS:KAXIS,IWSEL) = WSNORM(IAXIS:KAXIS) * MGNRM**(-1._EB)
      GEOMETRY(IG)%FACES_AREA(IWSEL) = MGNRM/2._EB
      ! Total Area and Volume for GEOMETRY(IG).
      GEOMETRY(IG)%GEOM_AREA  = GEOMETRY(IG)%GEOM_AREA  + GEOMETRY(IG)%FACES_AREA(IWSEL)
      GEOMETRY(IG)%GEOM_VOLUME= GEOMETRY(IG)%GEOM_VOLUME+ & ! Divergence theorem with F = x i, assumes we have a volume.
      GEOMETRY(IG)%FACES_NORMAL(IAXIS,IWSEL)*XCEN*GEOMETRY(IG)%FACES_AREA(IWSEL)
      
   ENDDO
   
   NWSEDG = 0
   DO IWSEL=1,NWSEL
      
      WSELEM(NOD1:NOD3) = GEOMETRY(IG)%FACES(NODS_WSEL*(IWSEL-1)+1:NODS_WSEL*IWSEL)
      
      DO IEDGE=EDG1,EDG3
         
         SEG(NOD1:NOD2) = WSELEM(NOD1:NOD2)
         
         ! Test triangles edge iedge is already on list
         ! GEOMETRY(IG)%EDGES. Makes use of fact that two triangles
         ! sharing an edge have opposite connectivity for it (right hand 
         ! rule for connectivity for normal outside solid).
         INLIST = .FALSE.
         DO IEDLIST=1,NWSEDG
            ! TEST SEG(2)=EDGE(1) AND SEG(1)=EDGE(2): 
            IF ( (SEG(NOD1) == GEOMETRY(IG)%EDGES(NOD2,IEDLIST)) .AND. &
                 (SEG(NOD2) == GEOMETRY(IG)%EDGES(NOD1,IEDLIST)) ) THEN
               INLIST = .TRUE.
               EXIT
            ENDIF
         ENDDO
         IF (INLIST) THEN ! LOCAL EDGE ALREADY ON LIST.
             GEOMETRY(IG)%EDGE_FACES(1,IEDLIST)   = 2
             GEOMETRY(IG)%EDGE_FACES(4,IEDLIST)   = IWSEL;
             GEOMETRY(IG)%EDGE_FACES(5,IEDLIST)   = IEDGE;    
             GEOMETRY(IG)%FACE_EDGES(IEDGE,IWSEL) = IEDLIST;
         ELSE ! NEW ENTRY ON LIST
             NWSEDG = NWSEDG + 1;
             GEOMETRY(IG)%EDGES(NOD1:NOD2,NWSEDG) = SEG(NOD1:NOD2)
             GEOMETRY(IG)%EDGE_FACES(1,NWSEDG)    = 1
             GEOMETRY(IG)%EDGE_FACES(2,NWSEDG)    = IWSEL
             GEOMETRY(IG)%EDGE_FACES(3,NWSEDG)    = IEDGE
             GEOMETRY(IG)%FACE_EDGES(IEDGE,IWSEL) = NWSEDG
         ENDIF
         
         WSELEM=CSHIFT(WSELEM,1)
         
      ENDDO
   ENDDO
   
   GEOMETRY(IG)%N_EDGES = NWSEDG
   
ENDDO GEOMETRY_LOOP

! Print out of computed result:
! DO IG=1,N_GEOMETRY
!    NWSEL = GEOMETRY(IG)%N_FACES
!    DO IWSEL=1,NWSEL
!       print*, IWSEL,GEOMETRY(IG)%FACES_AREA(IWSEL)
!    ENDDO
!    DO IWSEL=1,NWSEL
!       print*, IWSEL,GEOMETRY(IG)%FACES_NORMAL(IAXIS:KAXIS,IWSEL)
!    ENDDO
!    print*, "EDGES="
!    DO NWSEDG=1,GEOMETRY(IG)%N_EDGES
!       print*, NWSEDG,GEOMETRY(IG)%EDGES(NOD1:NOD2,NWSEDG)
!    ENDDO
!    DO NWSEDG=1,GEOMETRY(IG)%N_EDGES
!       print*, GEOMETRY(IG)%EDGE_FACES(1:5,NWSEDG)
!    ENDDO
!    print*, "FACES="
!    DO IWSEL=1,NWSEL
!       print*, IWSEL,GEOMETRY(IG)%FACE_EDGES(EDG1:EDG3,IWSEL)
!    ENDDO
! ENDDO

RETURN
END SUBROUTINE IBM_INIT_GEOM

! ------------------------- GET_X2_VERTVAR --------------------------------------

SUBROUTINE GET_X2_VERTVAR(X1AXIS,X2LO,X2HI,NM,I,KK)

INTEGER, INTENT(IN) :: X1AXIS,X2LO,X2HI,NM,I,KK

! Local Variables:
INTEGER :: ICRS,ICRS1,JSTR,JEND,JJ

! Work By Edge, Only one x1axis=IAXIS needs to be used:
IF ( X1AXIS == IAXIS ) THEN
   
   ! Case of GG, SS points:
   DO ICRS=1,IBM_N_CRS
      ! If is_crs(icrs) == GG, SS, SGG see if crossing is
      ! exactly on a Cartesian cell vertex:
      SELECT CASE(IBM_IS_CRS(ICRS))
      CASE(IBM_GG,IBM_SS)
         
         ! Optimized and will ONLY work for Uniform Grids:
         JSTR = MAX(X2LO,   FLOOR((IBM_SVAR_CRS(ICRS)-GEOMEPS-X2FACE(X2LO))/DX2FACE(X2LO)) + X2LO)
         JEND = MIN(X2HI, CEILING((IBM_SVAR_CRS(ICRS)+GEOMEPS-X2FACE(X2LO))/DX2FACE(X2LO)) + X2LO)
         
         DO JJ=JSTR,JEND
            ! Crossing on Vertex?
            IF( ABS(X2FACE(JJ)-IBM_SVAR_CRS(ICRS)) < GEOMEPS ) THEN
               MESHES(NM)%VERTVAR(I,jj,kk,IBM_VGSC) = IBM_SOLID
               EXIT
            ENDIF
         ENDDO
      
      END SELECT
   ENDDO
   
   ! Other cases:
   DO ICRS=1,IBM_N_CRS-1
      ! Case GS-SG: All Cartesian vertices are set to IBM_SOLID.
      IF (IBM_IS_CRS(ICRS) == IBM_GS) THEN
         ! Find corresponding SG intersection:
         DO ICRS1=ICRS+1,IBM_N_CRS 
            IF (IBM_IS_CRS(ICRS1) == IBM_SG) EXIT
         ENDDO
         ! Optimized for UG:
         JSTR = MAX(X2LO, CEILING(( IBM_SVAR_CRS(ICRS)-GEOMEPS-X2FACE(X2LO))/DX2FACE(X2LO)) + X2LO)
         JEND = MIN(X2HI,   FLOOR((IBM_SVAR_CRS(ICRS1)+GEOMEPS-X2FACE(X2LO))/DX2FACE(X2LO)) + X2LO)
                
         DO JJ=JSTR,JEND
            MESHES(NM)%VERTVAR(I,jj,kk,IBM_VGSC) = IBM_SOLID
         ENDDO
      ENDIF
   ENDDO
   
ENDIF

RETURN
END SUBROUTINE GET_X2_VERTVAR

! ---------------------------- READ_GEOM ----------------------------------------

SUBROUTINE READ_GEOM
USE BOXTETRA_ROUTINES, ONLY: TETRAHEDRON_VOLUME, REMOVE_DUPLICATE_VERTS

! input &GEOM lines

CHARACTER(30) :: ID,SURF_ID, MATL_ID
CHARACTER(60) :: BNDC_FILENAME, GEOC_FILENAME
CHARACTER(30) :: TEXTURE_MAPPING
CHARACTER(MESSAGE_LENGTH) :: MESSAGE, BUFFER

INTEGER :: MAX_IDS=0
CHARACTER(30),  ALLOCATABLE, DIMENSION(:) :: GEOM_IDS
REAL(EB), ALLOCATABLE, DIMENSION(:) :: DAZIM, DELEV
REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: DSCALE, DXYZ0, DXYZ

INTEGER :: MAX_ZVALS=0
REAL(EB), ALLOCATABLE, DIMENSION(:) :: ZVALS

INTEGER :: MAX_VERTS=0
REAL(EB), ALLOCATABLE, TARGET, DIMENSION(:) :: VERTS
LOGICAL, ALLOCATABLE, DIMENSION(:) :: IS_EXTERNAL

INTEGER :: MAX_FACES=0, MAX_VOLUS=0
INTEGER, ALLOCATABLE, TARGET, DIMENSION(:) :: FACES, VOLUS, OFACES
REAL(EB), ALLOCATABLE, DIMENSION(:) :: TFACES

REAL(EB) :: AZIM, ELEV, SCALE(3), XYZ0(3), XYZ(3)
REAL(EB) :: AZIM_DOT, ELEV_DOT, SCALE_DOT(3), XYZ_DOT(3)
REAL(EB) :: GROTATE, GROTATE_DOT, GAXIS(3)
REAL(EB), PARAMETER :: MAX_VAL=1.0E20_EB
REAL(EB) :: SPHERE_ORIGIN(3), SPHERE_RADIUS
REAL(EB) :: TEXTURE_ORIGIN(3), TEXTURE_SCALE(2)
LOGICAL :: AUTO_TEXTURE
REAL(EB) :: XB(6), DX
INTEGER :: N_VERTS, N_FACES, N_FACES_TEMP, N_VOLUS, N_ZVALS
INTEGER :: MATL_INDEX
INTEGER :: IOS,IZERO,N, I, J, K, IJ, NSUB_GEOMS, GEOM_INDEX
INTEGER :: I11, I12, I21, I22
INTEGER :: GEOM_TYPE, NXB, IJK(3)
INTEGER :: N_LEVELS, N_LAT, N_LONG, SPHERE_TYPE
TYPE (MESH_TYPE), POINTER :: M=>NULL()
INTEGER, POINTER, DIMENSION(:) :: FACEI, FACEJ, FACE_FROM, FACE_TO
REAL(EB) :: BOX_XYZ(3)
INTEGER :: BOXVERTLIST(8), NI, NIJ
REAL(EB) :: ZERO3(3)=(/0.0_EB,0.0_EB,0.0_EB/)
REAL(EB) :: ZMIN
INTEGER, POINTER, DIMENSION(:) :: VOL
INTEGER :: IVOL
REAL(EB) :: VOLUME
REAL(EB), POINTER, DIMENSION(:) :: V1, V2, V3, V4
LOGICAL :: HAVE_SURF, HAVE_MATL
INTEGER :: SORT_FACES
INTEGER :: FIRST_FACE_INDEX
REAL(EB) :: TXMIN, TXMAX, TYMIN, TYMAX, TX, TY

LOGICAL COMPONENT_ONLY
LOGICAL, ALLOCATABLE, DIMENSION(:) :: DEFAULT_COMPONENT_ONLY
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL(), GSUB=>NULL()

NAMELIST /GEOM/ AUTO_TEXTURE, AZIM, AZIM_DOT, COMPONENT_ONLY, CUTCELLS, DAZIM, DELEV, DSCALE, DT_BNDC, DT_GEOC, DXYZ0, DXYZ, &
                ELEV, ELEV_DOT, FACES, GAXIS, GEOM_IDS, GROTATE, GROTATE_DOT, ID, IJK, &
                MATL_ID, N_LAT, N_LEVELS, N_LONG, SCALE, SCALE_DOT, &
                SPHERE_ORIGIN, SPHERE_RADIUS, SPHERE_TYPE, SURF_ID,  &
                TEXTURE_MAPPING, TEXTURE_ORIGIN, TEXTURE_SCALE, &
                VERTS, VOLUS, XB, XYZ0, XYZ, XYZ_DOT, ZMIN, ZVALS, &
                BNDC_FILENAME, GEOC_FILENAME

! first pass - determine max number of ZVALS, VERTS, FACES, VOLUS and IDS over all &GEOMs

N_GEOMETRY=0
REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
COUNT_GEOM_LOOP: DO
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_GEOM_LOOP
   READ(LU_INPUT,'(A)')BUFFER
   N_GEOMETRY=N_GEOMETRY+1
   CALL GET_GEOM_INFO(LU_INPUT,MAX_ZVALS,MAX_VERTS,MAX_FACES,MAX_VOLUS,MAX_IDS)
ENDDO COUNT_GEOM_LOOP
REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
IF (N_GEOMETRY==0) RETURN 

! allocate temporary buffers used when reading &GEOM namelists

CALL ALLOCATE_BUFFERS

! second pass - count and check &GEOM lines

N_GEOMETRY=0

REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
COUNT_GEOM_LOOP2: DO
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_GEOM_LOOP2
   READ(LU_INPUT,NML=GEOM,END=21,ERR=22,IOSTAT=IOS)
   N_GEOMETRY=N_GEOMETRY+1
   22 IF (IOS>0) CALL SHUTDOWN('ERROR: problem with GEOM line')
ENDDO COUNT_GEOM_LOOP2
21 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
IF (N_GEOMETRY==0) RETURN

! Allocate GEOMETRY array

ALLOCATE(GEOMETRY(0:N_GEOMETRY),STAT=IZERO)
CALL ChkMemErr('READ_GEOM','GEOMETRY',IZERO)

ALLOCATE(DEFAULT_COMPONENT_ONLY(N_GEOMETRY),STAT=IZERO)
CALL ChkMemErr('READ_GEOM','DEFAULT_COMPONENT_ONLY',IZERO)

! third pass - check for groups

! set default for COMPONENT_ONLY
!   if an object is in a GEOM_IDS list then COMPONENT_ONLY for this object is initially 
!       set to .TRUE. (is only drawn as part of a larger group)
!   if an object is not in any GEOM_IDS list then COMPONENT_ONLY for this object is initially 
!       set to .FALSE. (is drawn by default)
READ_GEOM_LOOP0: DO N=1,N_GEOMETRY
   G=>GEOMETRY(N)
   
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_GEOM_LOOP0
   
   ! Set defaults
   GEOM_IDS = ''
   BNDC_FILENAME = 'null'
   GEOC_FILENAME = 'null'

   ! Read the GEOM line
   
   READ(LU_INPUT,GEOM,END=25)

   DEFAULT_COMPONENT_ONLY(N) = .FALSE.
   DO I = 1, MAX_IDS
      IF (GEOM_IDS(I)=='') EXIT
      IF (N>1) THEN
         GEOM_INDEX = GET_GEOM_ID(GEOM_IDS(I),N-1)
         IF (GEOM_INDEX>=1 .AND. GEOM_INDEX<=N-1) THEN
            DEFAULT_COMPONENT_ONLY(GEOM_INDEX) = .TRUE.
         ENDIF
      ENDIF
   ENDDO
   
ENDDO READ_GEOM_LOOP0
25 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

! fourth pass - read GEOM data

READ_GEOM_LOOP: DO N=1,N_GEOMETRY
   G=>GEOMETRY(N)
   
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_GEOM_LOOP
   
   CALL SET_GEOM_DEFAULTS
   READ(LU_INPUT,GEOM,END=35)
   
   ! count VERTS
   
   N_VERTS=0
   DO I = 1, MAX_VERTS
      IF (ANY(VERTS(3*I-2:3*I)>=MAX_VAL)) EXIT
      N_VERTS = N_VERTS+1
   ENDDO
   
   ! count FACES
   
   N_FACES=0
   DO I = 1, MAX_FACES
      IF (ANY(FACES(3*I-2:3*I)==0)) EXIT
      N_FACES = N_FACES+1
   ENDDO
   TFACES(1:6*MAX_FACES) = -1.0_EB
   
   ! count VOLUS
   
   N_VOLUS=0
   DO I = 1, MAX_VOLUS
      IF (ANY(VOLUS(4*I-3:4*I)==0)) EXIT
      N_VOLUS = N_VOLUS+1
   ENDDO

   ! count ZVALS
   
   N_ZVALS=0
   DO I = 1, MAX_ZVALS
      IF (ZVALS(I)>MAX_VAL) EXIT
      N_ZVALS=N_ZVALS+1
   ENDDO

   !--- setup a 2D surface (terrain) object (ZVALS keyword )
   
   ZVALS_IF: IF (N_ZVALS>0) THEN
      GEOM_TYPE = 3
      CALL CHECK_XB(XB)
      IF (N_ZVALS/=IJK(1)*IJK(2) ) THEN
         WRITE(MESSAGE,'(A,I4,A,I4)') 'ERROR: Expected ',IJK(1)*IJK(2),' Z values, found ',N_ZVALS
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      IF (IJK(1)<2 .OR. IJK(2)<2) THEN
         CALL SHUTDOWN('ERROR: IJK(1) and IJK(2) on &GEOM line  needs to be at least 2')
      ENDIF
      NXB=0
      DO I = 1, 4 ! first 4 XB values must be set, don't care about 5th and 6th
        IF (XB(I)<MAX_VAL) NXB=NXB+1
      ENDDO
      IF (NXB<4) THEN
         CALL SHUTDOWN('ERROR: At least 4 XB values (xmin, xmax, ymin, ymax) required when using ZVALS')
      ENDIF
      ALLOCATE(G%ZVALS(N_ZVALS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%ZVALS',IZERO)
      N_FACES=2*(IJK(1)-1)*(IJK(2)-1)
      N_VERTS=IJK(1)*IJK(2)

      ! define terrain vertices

      IJ = 1
      DO J = 1, IJK(2)
         DO I = 1, IJK(1)
            VERTS(3*IJ-2) = (XB(1)*REAL(IJK(1)-I,EB) + XB(2)*REAL(I-1,EB))/REAL(IJK(1)-1,EB)
            VERTS(3*IJ-1) = (XB(4)*REAL(IJK(2)-J,EB) + XB(3)*REAL(J-1,EB))/REAL(IJK(2)-1,EB)
            VERTS(3*IJ) = ZVALS(IJ)
            IJ = IJ + 1
         ENDDO
      ENDDO

! define terrain faces
!    I21   I22
!    I11   I21      
      IJ = 1
      DO J = 1, IJK(2) - 1
         DO I = 1, IJK(1) - 1
            I21 = (J-1)*IJK(1) + I
            I22 = I21 + 1
            I11 = I21 + IJK(1)
            I12 = I11 + 1
            
            FACES(3*IJ-2) = I11
            FACES(3*IJ-1) = I21
            FACES(3*IJ) = I22 
            IJ = IJ + 1
            
            FACES(3*IJ-2) = I11
            FACES(3*IJ-1) = I22
            FACES(3*IJ) = I12
            IJ = IJ + 1
         ENDDO 
      ENDDO 
      G%ZVALS(1:N_ZVALS) = ZVALS(1:N_ZVALS)
      CALL EXTRUDE_SURFACE(ZMIN,VERTS,MAX_VERTS,N_VERTS,FACES,N_FACES,VOLUS,MAX_VOLUS, N_VOLUS)
      N_FACES=0
   ENDIF ZVALS_IF
   
   !--- setup a block object (XB keyword )
   
   NXB=0
   DO I = 1, 6
      IF (XB(I)<MAX_VAL) NXB=NXB+1
   ENDDO
   IF (NXB==6 .AND. N_ZVALS==0) THEN
      GEOM_TYPE = 1
      CALL CHECK_XB(XB)
      G%XB=XB

      ! make IJK(1), IJK(2), IJK(3) consistent with grid resolution (if not specified on &GEOM line)
 
      M => MESHES(1)
      DX = MIN(M%DXMIN,M%DYMIN,M%DZMIN)
      IF (IJK(1)<2) IJK(1) = MAX(2,INT((XB(2)-XB(1)/DX)+1))
      IF (IJK(2)<2) IJK(2) = MAX(2,INT((XB(4)-XB(3)/DX)+1))
      IF (IJK(3)<2) IJK(3) = MAX(2,INT((XB(6)-XB(5)/DX)+1))

! define verts in box

      N_VERTS = 0
      DO K = 0, IJK(3)-1
         BOX_XYZ(3) = (REAL(IJK(3)-1-K,EB)*XB(5) + REAL(K,EB)*XB(6))/REAL(IJK(3)-1,EB)
         DO J = 0, IJK(2)-1
            BOX_XYZ(2) = (REAL(IJK(2)-1-J,EB)*XB(3) + REAL(J,EB)*XB(4))/REAL(IJK(2)-1,EB)
            DO I = 0, IJK(1)-1
               BOX_XYZ(1) = (REAL(IJK(1)-1-I,EB)*XB(1) + REAL(I,EB)*XB(2))/REAL(IJK(1)-1,EB)
               VERTS(3*N_VERTS+1:3*N_VERTS+3) =  BOX_XYZ(1:3)
               N_VERTS = N_VERTS + 1
            ENDDO
         ENDDO
      ENDDO
      
! define tetrahedrons in box
      
      N_VOLUS = 0
      NI = IJK(1)
      NIJ = IJK(1)*IJK(2)
      DO K = 0, IJK(3)-2
         DO J = 0, IJK(2)-2
            DO I = 0, IJK(1)-2
            
!     8-------7
!   / .     / |
! 5-------6   |
! |   .   |   |
! |   .   |   |
! |   4-------3
! | /     | /
! 1-------2
               BOXVERTLIST(1) = K*NIJ + J*NI + I + 1
               BOXVERTLIST(2) = BOXVERTLIST(1) + 1
               BOXVERTLIST(3) = BOXVERTLIST(2) + NI
               BOXVERTLIST(4) = BOXVERTLIST(3) - 1
               BOXVERTLIST(5) = BOXVERTLIST(1) + NIJ
               BOXVERTLIST(6) = BOXVERTLIST(2) + NIJ
               BOXVERTLIST(7) = BOXVERTLIST(3) + NIJ
               BOXVERTLIST(8) = BOXVERTLIST(4) + NIJ
               CALL BOX2TETRA(BOXVERTLIST,VOLUS(4*N_VOLUS+1:4*N_VOLUS+20))
               N_VOLUS = N_VOLUS + 5
            ENDDO
         ENDDO
      ENDDO
      N_FACES=0
   ENDIF

   ! setup a sphere object (SPHERE_RADIUS and SPHERE_ORIGIN keywords)
   
   IF (SPHERE_RADIUS<MAX_VAL .AND. &
      SPHERE_ORIGIN(1)<MAX_VAL .AND. SPHERE_ORIGIN(2)<MAX_VAL .AND. SPHERE_ORIGIN(3)<MAX_VAL) THEN
      GEOM_TYPE = 2
      
      M => MESHES(1)
      DX = M%DXMIN

      ! 2*PI*R/(5*2^N_LEVELS) ~= DX,   solve for N_LEVELS

      IF (SPHERE_RADIUS<100.0_EB*TWO_EPSILON_EB) SPHERE_RADIUS = 100.0_EB*TWO_EPSILON_EB

      IF (SPHERE_TYPE/=2) SPHERE_TYPE = 1
      IF (N_LEVELS<0 .AND. N_LAT>0 .AND. N_LONG>0) SPHERE_TYPE = 2
      IF (SPHERE_TYPE==1) THEN
         IF (N_LEVELS==-1) N_LEVELS = INT(LOG(2.0_EB*PI*SPHERE_RADIUS/(5.0_EB*DX))/LOG(2.0_EB))
         N_LEVELS = MIN(5,MAX(0,N_LEVELS))
      ELSE
         IF (N_LONG<6) N_LONG = MAX(6,INT(2.0_EB*PI*SPHERE_RADIUS/DX)+1)
         IF (N_LAT<3)  N_LAT = MAX(3,INT(PI*SPHERE_RADIUS/DX)+1)
      ENDIF
      
      IF (SPHERE_TYPE==1) THEN
         CALL INIT_SPHERE(N_LEVELS,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,VERTS,FACES)
      ELSE
         CALL INIT_SPHERE2(N_VERTS,N_FACES,N_LAT,N_LONG,VERTS,FACES)
      ENDIF
      CALL EXTRUDE_SPHERE(ZERO3,VERTS,MAX_VERTS,N_VERTS,FACES,N_FACES,VOLUS,MAX_VOLUS, N_VOLUS)
      N_FACES=0;

      DO I = 0, N_VERTS-1
         VERTS(3*I+1:3*I+3) = SPHERE_ORIGIN(1:3) + SPHERE_RADIUS*VERTS(3*I+1:3*I+3)
      ENDDO
   ENDIF

   G%N_LEVELS = N_LEVELS
   G%SPHERE_ORIGIN = SPHERE_ORIGIN
   G%SPHERE_RADIUS = SPHERE_RADIUS
   G%IJK = IJK
   G%COMPONENT_ONLY = COMPONENT_ONLY
   G%GEOM_TYPE = GEOM_TYPE
   G%BNDC_FILENAME = BNDC_FILENAME
   G%GEOC_FILENAME = GEOC_FILENAME
   
   IF (GEOC_FILENAME/='null' .AND. N_GEOMETRY > 1 ) THEN
      CALL SHUTDOWN('ERROR: only one &GEOM line permitted when defining coupled geometries (the GEOC_FILENAME keyword)')
   ENDIF
      
   !--- setup groups
   
   NSUB_GEOMS = 0
   DO I = 1, MAX_IDS
      IF (GEOM_IDS(I)=='') EXIT
      NSUB_GEOMS = NSUB_GEOMS+1
   ENDDO
   IF (NSUB_GEOMS>0) THEN
      ALLOCATE(G%SUB_GEOMS(NSUB_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%SUB_GEOMS',IZERO)
      
      ALLOCATE(G%DSCALE(3,NSUB_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%DSCALE',IZERO)
      
      ALLOCATE(G%DAZIM(NSUB_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%DAZIM',IZERO)
      
      ALLOCATE(G%DELEV(NSUB_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%DELEV',IZERO)
      
      ALLOCATE(G%DXYZ0(3,NSUB_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%DXYZ0',IZERO)
      
      ALLOCATE(G%DXYZ(3,NSUB_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%DXYZ',IZERO)

      N_FACES = 0 ! ignore vertex and face entries if there are any GEOM_IDS
      N_VERTS = 0
      N_VOLUS = 0
   ENDIF
   G%NSUB_GEOMS=NSUB_GEOMS
   
   ! remove duplicate vertices

   FIRST_FACE_INDEX=1
   CALL REMOVE_DUPLICATE_VERTS(N_VERTS,N_FACES,N_VOLUS,MAX_VERTS,MAX_FACES,MAX_VOLUS,FIRST_FACE_INDEX,VERTS,FACES,VOLUS)

   ! wrap up
   
   G%ID = ID
   G%N_VOLUS_BASE = N_VOLUS
   G%N_FACES_BASE = N_FACES
   G%N_VERTS_BASE = N_VERTS
   
   IF (SURF_ID=='null') THEN
      SURF_ID = 'INERT'
      HAVE_SURF=.FALSE.
   ENDIF
   G%SURF_ID = SURF_ID
   G%HAVE_SURF = HAVE_SURF

   IF (MATL_ID=='null') THEN
      HAVE_MATL = .FALSE.
   ENDIF
   G%MATL_ID = MATL_ID
   G%HAVE_MATL = HAVE_MATL
   
   IF (.NOT.AUTO_TEXTURE .AND. N_VERTS>0) THEN
      
      TXMIN = VERTS(1)
      TXMAX = TXMIN
      TYMIN = VERTS(2)
      TYMAX = TYMIN
      DO I = 1, N_VERTS
         TX = VERTS(3*I-2)
         TY = VERTS(3*I-1)
         IF (TX<TXMIN)TXMIN=TX
         IF (TX>TXMAX)TXMAX=TX
         IF (TY<TYMIN)TYMIN=TY
         IF (TY>TYMAX)TYMAX=TY
      ENDDO
      TEXTURE_ORIGIN(1)=TXMIN
      TEXTURE_ORIGIN(2)=TYMIN
      TEXTURE_SCALE(1)=TXMAX-TXMIN
      TEXTURE_SCALE(2)=TYMAX-TYMIN
   ENDIF

   G%TEXTURE_ORIGIN = TEXTURE_ORIGIN
   G%TEXTURE_SCALE = TEXTURE_SCALE
   G%AUTO_TEXTURE = AUTO_TEXTURE
   IF ( TRIM(TEXTURE_MAPPING)/='SPHERICAL' .AND. TRIM(TEXTURE_MAPPING)/='RECTANGULAR') TEXTURE_MAPPING = 'RECTANGULAR'
   G%TEXTURE_MAPPING = TEXTURE_MAPPING

   ! setup volumes
   
   IF (N_VOLUS>0) THEN
      ALLOCATE(G%VOLUS(4*N_VOLUS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%VOLUS',IZERO)
      DO I = 0, N_VOLUS-1
         VOL(1:4)=> VOLUS(4*I+1:4*I+4)
         V1(1:3) => VERTS(3*VOL(1)-2:3*VOL(1))
         V2(1:3) => VERTS(3*VOL(2)-2:3*VOL(2))
         V3(1:3) => VERTS(3*VOL(3)-2:3*VOL(3))
         V4(1:3) => VERTS(3*VOL(4)-2:3*VOL(4))
         VOLUME = TETRAHEDRON_VOLUME(V3,V4,V2,V1) 
         IF ( VOLUME<0.0_EB ) THEN ! reorder vertices if tetrahedron volume is negative
            IVOL=VOL(3)
            VOL(3)=VOL(4)
            VOL(4)=IVOL
         ENDIF
      ENDDO
      G%VOLUS(1: 4*N_VOLUS) = VOLUS(1:4*N_VOLUS)
      IF (ANY(VOLUS(1:4*N_VOLUS)<1 .OR. VOLUS(1:4*N_VOLUS)>N_VERTS)) THEN
         CALL SHUTDOWN('ERROR: problem with GEOM, vertex index out of bounds')
      ENDIF

      ALLOCATE(G%MATLS(N_VOLUS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%MATLS',IZERO)
      MATL_INDEX = GET_MATL_INDEX(MATL_ID)
      IF (MATL_INDEX==0) THEN
         IF (TRIM(MATL_ID)=='null') THEN
           WRITE(MESSAGE,'(A)') 'ERROR: problem with GEOM, the material keyword, MATL_ID, is not defined.'
         ELSE
           WRITE(MESSAGE,'(3A)') 'ERROR: problem with GEOM, the material ',TRIM(MATL_ID),' is not defined.'
         ENDIF
         CALL SHUTDOWN(MESSAGE)
      ENDIF
      G%MATLS(1:N_VOLUS) = MATL_INDEX

      ! construct an array of external faces

      ! determine which tetrahedron faces are external
   
      IF (N_FACES==0) THEN   
         N_FACES = 4*N_VOLUS
         ALLOCATE(IS_EXTERNAL(0:N_FACES-1),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','IS_EXTERNAL',IZERO)
      
         IS_EXTERNAL(0:N_FACES-1)=.TRUE.  ! start off by assuming all faces are external
      
! reorder face indices so the the first index is always the smallest      
 
               
!              1 
!             /|\                       . 
!            / | \                      .
!           /  |  \                     . 
!          /   |   \                    .  
!         /    |    \                   . 
!        /     4     \                  . 
!       /     . .     \                 . 
!      /     .    .    \                .  
!     /    .        .   \               .  
!    /   .            .  \              . 
!   /  .               .  \             . 
!  / .                    .\            . 
! 2-------------------------3

         DO I = 0, N_VOLUS-1
            FACES(12*I+1) = VOLUS(4*I+1)
            FACES(12*I+2) = VOLUS(4*I+2)
            FACES(12*I+3) = VOLUS(4*I+3)
            CALL REORDER_VERTS(FACES(12*I+1:12*I+3))

            FACES(12*I+4) = VOLUS(4*I+1)
            FACES(12*I+5) = VOLUS(4*I+3)
            FACES(12*I+6) = VOLUS(4*I+4)
            CALL REORDER_VERTS(FACES(12*I+4:12*I+6))
         
            FACES(12*I+7) = VOLUS(4*I+1)
            FACES(12*I+8) = VOLUS(4*I+4)
            FACES(12*I+9) = VOLUS(4*I+2)
            CALL REORDER_VERTS(FACES(12*I+7:12*I+9))
         
            FACES(12*I+10) = VOLUS(4*I+2)
            FACES(12*I+11) = VOLUS(4*I+4)
            FACES(12*I+12) = VOLUS(4*I+3)
            CALL REORDER_VERTS(FACES(12*I+10:12*I+12))
         ENDDO
      
      ! find faces that match      
         
         SORT_FACES=1
         IF (SORT_FACES==1 ) THEN  ! o(n*log(n)) algorithm for determining external faces
            ALLOCATE(OFACES(N_FACES),STAT=IZERO)
            CALL ChkMemErr('READ_GEOM','OFACES',IZERO)
            CALL ORDER_FACES(OFACES,N_FACES)
            DO I = 1, N_FACES-1
               FACEI=>FACES(3*OFACES(I)-2:3*OFACES(I))
               FACEJ=>FACES(3*OFACES(I)+1:3*OFACES(I)+3)
               IF (FACEI(1)==FACEJ(1) .AND. &
                  MIN(FACEI(2),FACEI(3))==MIN(FACEJ(2),FACEJ(3)) .AND. &
                  MAX(FACEI(2),FACEI(3))==MAX(FACEJ(2),FACEJ(3))) THEN
                  IS_EXTERNAL(OFACES(I))=.FALSE.
                  IS_EXTERNAL(OFACES(I-1))=.FALSE.
                  IF (FACEI(2)==FACEJ(2) .AND. FACEI(3)==FACEJ(3)) THEN
                     WRITE(LU_ERR,*) 'WARNING: duplicate faces found:', FACEI(1),FACEI(2),FACEI(3)
                  ENDIF
               ENDIF
            
            ENDDO
         ELSE
            DO I = 0, N_FACES-1  ! o(n^2) algorithm for determining external faces
               FACEI=>FACES(3*I+1:3*I+3)
               DO J = 0, N_FACES-1
                  IF (I==J) CYCLE
                  FACEJ=>FACES(3*J+1:3*J+3)
                  IF (FACEI(1)/=FACEJ(1)) CYCLE  
                  IF ((FACEI(2)==FACEJ(2) .AND. FACEI(3)==FACEJ(3)) .OR. &
                     (FACEI(2)==FACEJ(3) .AND. FACEI(3)==FACEJ(2))) THEN
                     IS_EXTERNAL(I) = .FALSE.
                     IS_EXTERNAL(J) = .FALSE.
                  ENDIF
               ENDDO
            ENDDO
         ENDIF

      ! create new FACES index array keeping only external faces
      
         N_FACES_TEMP = N_FACES  
         N_FACES=0
         DO I = 0, N_FACES_TEMP-1
            IF (IS_EXTERNAL(I)) THEN
               FACE_FROM=>FACES(3*I+1:3*I+3)
               FACE_TO=>FACES(3*N_FACES+1:3*N_FACES+3)
               FACE_TO(1:3) = FACE_FROM(1:3)
               N_FACES=N_FACES+1
            ENDIF
         ENDDO
         G%N_FACES_BASE = N_FACES
         CALL COMPUTE_TEXTURES(VERTS,FACES,TFACES,MAX_VERTS,MAX_FACES,N_FACES)
      ENDIF
   ENDIF

   IF (N_FACES>0) THEN
      ALLOCATE(G%FACES(3*N_FACES),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%FACES',IZERO)
      G%FACES(1:3*N_FACES) = FACES(1:3*N_FACES)

      IF ( ANY(FACES(1:3*N_FACES)<1 .OR. FACES(1:3*N_FACES)>N_VERTS) ) THEN
         CALL SHUTDOWN('ERROR: problem with GEOM, vertex index out of bounds')
      ENDIF

      ALLOCATE(G%TFACES(6*N_FACES),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%TFACES',IZERO)
      G%TFACES(1:6*N_FACES) = TFACES(1:6*N_FACES)

      ALLOCATE(G%SURFS(N_FACES),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%SURFS',IZERO)
      G%SURFS(1:N_FACES) = GET_SURF_INDEX(SURF_ID)
   ENDIF

   IF (N_VERTS>0) THEN
      ALLOCATE(G%VERTS_BASE(3*N_VERTS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%VERTS_BASE',IZERO)
      G%VERTS_BASE(1:3*N_VERTS) = VERTS(1:3*N_VERTS)

      ALLOCATE(G%VERTS(3*N_VERTS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','G%VERTS',IZERO)
   ENDIF
   
   DO I = 1, NSUB_GEOMS
      GEOM_INDEX = GET_GEOM_ID(GEOM_IDS(I),N-1)
      IF (GEOM_INDEX>=1 .AND. GEOM_INDEX<=N-1) THEN
         G%SUB_GEOMS(I) = GEOM_INDEX
      ELSE
         CALL SHUTDOWN('ERROR: problem with GEOM '//TRIM(G%ID)//' line, '//TRIM(GEOM_IDS(I))//' not yet defined.')
      ENDIF
   ENDDO
   
   ! use GROTATE/GAXIS or AZIM/ELEV but not both

   IF (ANY(GAXIS(1:3)<MAX_VAL) .OR. GROTATE<MAX_VAL .OR. GROTATE_DOT<MAX_VAL) THEN
      IF (GAXIS(1)>MAX_VAL) GAXIS(1) = 0.0_EB
      IF (GAXIS(2)>MAX_VAL) GAXIS(2) = 0.0_EB
      IF (GAXIS(3)>MAX_VAL) GAXIS(3) = 0.0_EB
      AZIM = 0.0_EB
      ELEV = 0.0_EB
      AZIM_DOT = 0.0_EB
      ELEV_DOT = 0.0_EB
      
      IF (GROTATE>MAX_VAL) GROTATE = 0.0_EB
      IF (GROTATE_DOT>MAX_VAL) GROTATE_DOT = 0.0_EB
      
      IF (ALL(ABS(GAXIS(1:3))<TWO_EPSILON_EB)) THEN
         GAXIS(1:3) = (/0.0_EB,0.0_EB,1.0_EB/)
      ELSE
         GAXIS = GAXIS/SQRT(DOT_PRODUCT(GAXIS,GAXIS))
      ENDIF
   ELSE
      GAXIS(1:3) = (/0.0_EB,0.0_EB,1.0_EB/)
      GROTATE = 0.0_EB
      GROTATE_DOT = 0.0_EB
   ENDIF
   
   G%XYZ0(1:3) = XYZ0(1:3)
   
   G%GAXIS = GAXIS
   G%GROTATE = GROTATE
   G%GROTATE_BASE = GROTATE
   G%GROTATE_DOT = GROTATE_DOT

   G%AZIM_BASE = AZIM
   G%AZIM_DOT = AZIM_DOT
   
   G%ELEV_BASE = ELEV
   G%ELEV_DOT = ELEV_DOT

   G%SCALE_BASE = SCALE
   G%SCALE_DOT(1:3) = SCALE_DOT(1:3)

   G%XYZ_BASE(1:3) = XYZ(1:3)
   G%XYZ_DOT(1:3) = XYZ_DOT(1:3)

   IF (ABS(AZIM_DOT)>TWO_EPSILON_EB .OR. ABS(ELEV_DOT)>TWO_EPSILON_EB .OR. &
       ANY(ABS(SCALE_DOT(1:3))>TWO_EPSILON_EB) .OR. ANY(ABS(XYZ_DOT(1:3) )>TWO_EPSILON_EB) .OR. GEOC_FILENAME/='null' ) THEN 
      G%IS_DYNAMIC = .TRUE.
      IS_GEOMETRY_DYNAMIC = .TRUE.
   ELSE
      G%IS_DYNAMIC = .FALSE.
   ENDIF

   NSUB_GEOMS_IF: IF (NSUB_GEOMS>0) THEN   

      ! if any component of a group is time dependent then the whole group is time dependent

      DO I = 1, NSUB_GEOMS
         GSUB=>GEOMETRY(G%SUB_GEOMS(I))

         IF (GSUB%IS_DYNAMIC) THEN
            G%IS_DYNAMIC = .TRUE.
            IS_GEOMETRY_DYNAMIC = .TRUE.
            EXIT
         ENDIF
      ENDDO
      
      G%DXYZ0(1:3,1:NSUB_GEOMS) = DXYZ0(1:3,1:NSUB_GEOMS)

      G%DAZIM(1:NSUB_GEOMS) = DAZIM(1:NSUB_GEOMS)
      G%DELEV(1:NSUB_GEOMS) = DELEV(1:NSUB_GEOMS)
      G%DSCALE(1:3,1:NSUB_GEOMS) = DSCALE(1:3,1:NSUB_GEOMS)
      G%DXYZ(1:3,1:NSUB_GEOMS) = DXYZ(1:3,1:NSUB_GEOMS)

      ! allocate memory for vertex and face arrays for GEOMs that contain groups (entres in GEOM_IDs )

      DO I = 1, NSUB_GEOMS
         GSUB=>GEOMETRY(G%SUB_GEOMS(I))
         G%N_VOLUS_BASE = G%N_VOLUS_BASE + GSUB%N_VOLUS_BASE
         G%N_FACES_BASE = G%N_FACES_BASE + GSUB%N_FACES_BASE
         G%N_VERTS_BASE = G%N_VERTS_BASE + GSUB%N_VERTS_BASE
      ENDDO

      IF (G%N_VOLUS_BASE>0) THEN
         ALLOCATE(G%VOLUS(4*G%N_VOLUS_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','VOLUS',IZERO)

         ALLOCATE(G%MATLS(G%N_VOLUS_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','G%MATLS',IZERO)
      ENDIF

      IF (G%N_FACES_BASE>0) THEN
         ALLOCATE(G%FACES(3*G%N_FACES_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','G%FACES',IZERO)
      
         ALLOCATE(G%SURFS(G%N_FACES_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','G%SURFS',IZERO)
         
         ALLOCATE(G%TFACES(6*G%N_FACES_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','G%TFACES',IZERO)
      ENDIF

      IF (G%N_VERTS_BASE>0) THEN
         ALLOCATE(G%VERTS_BASE(3*G%N_VERTS_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','G%VERTS',IZERO)

         ALLOCATE(G%VERTS(3*G%N_VERTS_BASE),STAT=IZERO)
         CALL ChkMemErr('READ_GEOM','G%VERTS',IZERO)
      ENDIF

   ENDIF NSUB_GEOMS_IF
ENDDO READ_GEOM_LOOP
35 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
   
GEOMETRY_CHANGE_STATE = 0   
DO I = 1, N_GEOMETRY
   G=>GEOMETRY(I)
   IF (G%GEOC_FILENAME/='null') THEN
      GEOMETRY_CHANGE_STATE = 2
      EXIT
   ENDIF
   IF (G%IS_DYNAMIC) GEOMETRY_CHANGE_STATE=1
ENDDO

CALL CONVERTGEOM(T_BEGIN) 

CONTAINS

! ---------------------------- GET_GEOM_INFO ----------------------------------------

SUBROUTINE GET_GEOM_INFO(LU_INPUT,MAX_ZVALS,MAX_VERTS,MAX_FACES,MAX_VOLUS,MAX_IDS)

! count numnber of various geometry types on the current &GEOM line
! for now assume a maximum value

INTEGER, INTENT(IN) :: LU_INPUT
INTEGER, INTENT(INOUT) :: MAX_ZVALS,MAX_VERTS,MAX_FACES,MAX_VOLUS,MAX_IDS

MAX_ZVALS=MAX(MAX_ZVALS,10000)
MAX_VOLUS=MAX(MAX_VOLUS,3*MAX_ZVALS,100000)
MAX_FACES=MAX(MAX_FACES,4*MAX_VOLUS,100000)
MAX_VERTS=MAX(MAX_VERTS,4*MAX_VOLUS,3*MAX_FACES,100000)
MAX_IDS=MAX(MAX_IDS,1000)

END SUBROUTINE GET_GEOM_INFO

! ---------------------------- ALLOCATE_BUFFERS ----------------------------------------

SUBROUTINE ALLOCATE_BUFFERS

ALLOCATE(DSCALE(3,MAX_IDS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','DSCALE',IZERO)

ALLOCATE(DXYZ0(3,MAX_IDS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','DXYZ0',IZERO)

ALLOCATE(DXYZ(3,MAX_IDS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','DXYZ',IZERO)

ALLOCATE(GEOM_IDS(MAX_IDS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','GEOM_IDS',IZERO)

ALLOCATE(DAZIM(MAX_IDS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','DAZIM',IZERO)

ALLOCATE(DELEV(MAX_IDS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','DELEV',IZERO)

ALLOCATE(ZVALS(MAX_ZVALS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','ZVALS',IZERO)

ALLOCATE(VERTS(3*MAX_VERTS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','VERTS',IZERO)

ALLOCATE(TFACES(6*MAX_FACES),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','TFACES',IZERO)

ALLOCATE(FACES(3*MAX_FACES),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','FACES',IZERO)

ALLOCATE(VOLUS(4*MAX_VOLUS),STAT=IZERO)
CALL ChkMemErr('ALLOCATE_BUFFERS','VOLUS',IZERO)

END SUBROUTINE ALLOCATE_BUFFERS

! ---------------------------- SET_GEOM_DEFAULTS ----------------------------------------

SUBROUTINE SET_GEOM_DEFAULTS
   
   ! Set defaults
   
   CUTCELLS=.FALSE.
   ZMIN=ZS_MIN
   COMPONENT_ONLY=DEFAULT_COMPONENT_ONLY(N)
   ID = 'geom'
   SURF_ID = 'null'
   MATL_ID = 'null'
   HAVE_SURF = .TRUE.
   HAVE_MATL = .TRUE.
   TEXTURE_ORIGIN = 0.0_EB
   TEXTURE_MAPPING = 'RECTANGULAR'
   TEXTURE_SCALE = 1.0_EB
   AUTO_TEXTURE = .FALSE.
   VERTS=1.001_EB*MAX_VAL
   ZVALS=1.001_EB*MAX_VAL
   XB=1.001_EB*MAX_VAL
   FACES=0
   VOLUS=0
   GEOM_IDS = ''
   IJK = 0
   IS_GEOMETRY_DYNAMIC = .FALSE.
   
   AZIM = 0.0_EB
   ELEV = 0.0_EB
   SCALE = 1.0_EB
   XYZ0 = 0.0_EB
   XYZ = 0.0_EB
   
   AZIM_DOT = 0.0_EB
   ELEV_DOT = 0.0_EB
   SCALE_DOT = 0.0_EB
   XYZ_DOT = 0.0_EB

   DAZIM = 0.0_EB
   DELEV = 0.0_EB
   DSCALE = 1.0_EB
   DXYZ0 = 0.0_EB
   DXYZ = 0.0_EB
   
   GAXIS(1:3) = 1.001_EB*MAX_VAL
   GROTATE = 1.001_EB*MAX_VAL
   GROTATE_DOT = 1.001_EB*MAX_VAL
   
   SPHERE_ORIGIN = 1.001_EB*MAX_VAL
   SPHERE_RADIUS = 1.001_EB*MAX_VAL
   N_LEVELS=-1
   N_LAT=-1
   N_LONG=-1
   SPHERE_TYPE=-1
   GEOM_TYPE = 0
END SUBROUTINE SET_GEOM_DEFAULTS

! ---------------------------- EXTRUDE_SPHERE ----------------------------------------

SUBROUTINE EXTRUDE_SPHERE(ZCENTER,VERTS,MAXVERTS,NVERTS,FACES,NFACES,VOLS,MAXVOLS, NVOLS)

! convert a closed surface defined by VERTS and FACES into a solid

INTEGER, INTENT(IN) :: NFACES, MAXVERTS,MAXVOLS
INTEGER, INTENT(INOUT) :: NVERTS
REAL(EB), INTENT(INOUT), TARGET :: VERTS(3*MAXVERTS)
INTEGER, INTENT(IN) :: FACES(3*NFACES)
INTEGER, INTENT(OUT) :: NVOLS
INTEGER, INTENT(OUT) :: VOLS(4*MAXVOLS)
REAL(EB), INTENT(IN) :: ZCENTER(3)

INTEGER :: I

! define a new vertex at ZCENTER
VERTS(3*NVERTS+1:3*NVERTS+3)=ZCENTER(1:3)

! form a tetrahedron using each face and the vertex ZCENTER
DO I = 1, NFACES
   VOLS(4*I-3:4*I)=(/FACES(3*I-2:3*I),NVERTS+1/)
ENDDO
NVERTS=NVERTS+1
NVOLS=NFACES

END SUBROUTINE EXTRUDE_SPHERE

! ---------------------------- EXTRUDE_SURFACE ----------------------------------------

SUBROUTINE EXTRUDE_SURFACE(ZMIN,VERTS,MAXVERTS,NVERTS,FACES,NFACES,VOLS,MAXVOLS, NVOLS)

! extend a 2D surface defined by VERTS and FACES to a plane defined by ZMIN

INTEGER, INTENT(IN) :: NFACES, MAXVERTS,MAXVOLS
INTEGER, INTENT(INOUT) :: NVERTS
REAL(EB), INTENT(INOUT), TARGET :: VERTS(3*MAXVERTS)
INTEGER, INTENT(IN) :: FACES(3*NFACES)
INTEGER, INTENT(OUT) :: NVOLS
INTEGER, INTENT(OUT) :: VOLS(4*MAXVOLS)
REAL(EB), INTENT(IN) :: ZMIN
INTEGER :: PRISM(6)

INTEGER :: I
REAL(EB), POINTER, DIMENSION(:) :: VNEW, VOLD

! define a new vertex on the plane z=ZMIN for each vertex in original list
DO I = 1, NVERTS
   VNEW=>VERTS(3*NVERTS+3*I-2:3*NVERTS+3*I)
   VOLD=>VERTS(3*I-2:3*I)
   VNEW(1:3)=(/VOLD(1:2),ZMIN/)
ENDDO
! construct 3 tetrahedrons for each prism (solid between original face and face on plane z=zplane)
DO I = 1, NFACES
   PRISM(1:3)=FACES(3*I-2:3*I)
   PRISM(4:6)=FACES(3*I-2:3*I)+NVERTS
   CALL PRISM2TETRA(PRISM,VOLS(12*I-11:12*I))
ENDDO
NVOLS=3*NFACES
NVERTS=2*NVERTS

END SUBROUTINE EXTRUDE_SURFACE

! ---------------------------- BOX2TETRA ----------------------------------------

SUBROUTINE BOX2TETRA(BOX,TETRAS)

! split a box defined by a list of 8 vertices (not necessarily cubic) into 5 tetrahedrons

!     8-------7
!   / .     / |
! 5-------6   |
! |   .   |   |
! |   .   |   |
! |   4-------3
! | /     | /
! 1-------2


INTEGER, INTENT(IN) :: BOX(8)
INTEGER, INTENT(OUT) :: TETRAS(1:20)

TETRAS(1:4)   = (/BOX(1),BOX(2),BOX(4),BOX(5)/)
TETRAS(5:8)   = (/BOX(2),BOX(6),BOX(7),BOX(5)/)
TETRAS(9:12)  = (/BOX(4),BOX(8),BOX(5),BOX(7)/)
TETRAS(13:16) = (/BOX(3),BOX(4),BOX(2),BOX(7)/)
TETRAS(17:20) = (/BOX(4),BOX(5),BOX(2),BOX(7)/)

END SUBROUTINE BOX2TETRA

! ---------------------------- PRISM2TETRA ----------------------------------------

SUBROUTINE PRISM2TETRA(PRISM,TETRAS)

! split a prism defined by a list of 6 vertices into 3 tetrahedrons

!       6
!      /.\                      . 
!    /  .  \                    .
!  /    .    \                  .
! 4-----------5
! |     .     |
! |     .     |
! |     3     |
! |    / \    |
! |  /     \  |
! |/         \|
! 1-----------2
INTEGER, INTENT(IN) :: PRISM(6)
INTEGER, INTENT(OUT) :: TETRAS(1:12)

TETRAS(1:4)   = (/PRISM(1),PRISM(6),PRISM(4),PRISM(5)/)
TETRAS(5:8)   = (/PRISM(1),PRISM(3),PRISM(6),PRISM(5)/)
TETRAS(9:12)  = (/PRISM(1),PRISM(2),PRISM(3),PRISM(5)/)

END SUBROUTINE PRISM2TETRA

! ---------------------------- SPLIT_TETRA ----------------------------------------

SUBROUTINE SPLIT_TETRA(VERTS,MAXVERTS,NVERTS,TETRAS)
! split a tetrahedron defined by a list of 4 vertices into 4 tetrahedrons

!        1 
!        | 
!       .|.  
!       .|.
!      . | .  
!     .  7 .  
!     .  |  . 
!    .   4  .
!    5  / \  6
!   .  /   \ .   
!   . /     \ .
!  . /       \ .    
!  ./         \.
!  /           \.
! 2-------------3

INTEGER, INTENT(IN) :: MAXVERTS
INTEGER, INTENT(INOUT) :: NVERTS
REAL(EB), INTENT(INOUT), TARGET :: VERTS(3*MAXVERTS)
INTEGER, INTENT(INOUT) :: TETRAS(16)

REAL(EB), POINTER, DIMENSION(:) :: VERT1, VERT2, VERT3, VERT4, VERT5, VERT6, VERT7
INTEGER :: TETRANEW(16)

VERT1=>VERTS(3*TETRAS(1)-2:3*TETRAS(1))
VERT2=>VERTS(3*TETRAS(2)-2:3*TETRAS(2))
VERT3=>VERTS(3*TETRAS(3)-2:3*TETRAS(3))
VERT4=>VERTS(3*TETRAS(4)-2:3*TETRAS(4))
VERT5=>VERTS(3*NVERTS+1:3*NVERTS+3)
VERT6=>VERTS(3*NVERTS+4:3*NVERTS+6)
VERT7=>VERTS(3*NVERTS+7:3*NVERTS+9)

! add 3 vertices
VERT5(1:3) = ( VERT1(1:3)+VERT2(1:3) )/2.0_EB
VERT6(1:3) = ( VERT1(1:3)+VERT3(1:3) )/2.0_EB
VERT7(1:3) = ( VERT1(1:3)+VERT4(1:3) )/2.0_EB
TETRAS(5)=NVERTS+1
TETRAS(6)=NVERTS+2
TETRAS(7)=NVERTS+3
NVERTS=NVERTS+3

TETRANEW(1:4)=(/TETRAS(1),TETRAS(5),TETRAS(6),TETRAS(7)/)
CALL PRISM2TETRA(TETRAS(2:7),TETRANEW(5:16))
TETRAS(1:16)=TETRANEW(1:16)

END SUBROUTINE SPLIT_TETRA

! ---------------------------- ORDER_FACES ----------------------------------------

SUBROUTINE ORDER_FACES(ORDER,N) ! 
INTEGER, INTENT(IN) :: N
INTEGER, INTENT(OUT) :: ORDER(1:N)

INTEGER, ALLOCATABLE, DIMENSION(:) :: WORK
INTEGER :: I, IZERO

DO I = 1, N
   ORDER(I) = I
ENDDO
ALLOCATE(WORK(N),STAT=IZERO)
CALL ChkMemErr('ORDER_FACES','WORK',IZERO)
CALL ORDER_FACES1(ORDER,WORK,1,N,N)
END SUBROUTINE ORDER_FACES

! ---------------------------- ORDER_FACES1 ----------------------------------------

RECURSIVE SUBROUTINE ORDER_FACES1(ORDER,WORK,LEFT,RIGHT,N)
INTEGER, INTENT(IN) :: N, LEFT, RIGHT
INTEGER, INTENT(INOUT) :: ORDER(1:N)
INTEGER :: TEMP
INTEGER :: I1, I2
INTEGER, INTENT(OUT) :: WORK(N)
INTEGER :: ICOUNT

INTEGER :: NMID

IF (RIGHT-LEFT>1) THEN
   NMID = (LEFT+RIGHT)/2
   CALL ORDER_FACES1(ORDER,WORK,LEFT,NMID,N)
   CALL ORDER_FACES1(ORDER,WORK,NMID+1,RIGHT,N)
   I1=LEFT
   I2=NMID+1
   ICOUNT=LEFT
   DO WHILE (I1<=NMID .OR. I2<=RIGHT)
      IF (I1<=NMID .AND. I2<=RIGHT) THEN
        IF (COMPARE_FACES(ORDER(I1),ORDER(I2))==-1) THEN
           WORK(ICOUNT)=ORDER(I1)
           I1=I1+1
        ELSE
           WORK(ICOUNT)=ORDER(I2)
           I2=I2+1
        ENDIF
      ELSE IF (I1<=NMID .AND. I2>RIGHT) THEN
         WORK(ICOUNT)=ORDER(I1)
         I1=I1+1
      ELSE IF (I1>NMID .AND. I2<=RIGHT) THEN
         WORK(ICOUNT)=ORDER(I2)
         I2=I2+1
      ENDIF
      ICOUNT=ICOUNT+1
   ENDDO
   ORDER(LEFT:RIGHT)=WORK(LEFT:RIGHT)
ELSE IF (RIGHT-LEFT==1) THEN
   IF (COMPARE_FACES(ORDER(LEFT),ORDER(RIGHT))==1) RETURN
   TEMP=ORDER(LEFT)
   ORDER(LEFT) = ORDER(RIGHT)
   ORDER(RIGHT) = TEMP
ENDIF
END SUBROUTINE ORDER_FACES1

! ---------------------------- COMPARE_FACES ----------------------------------------

INTEGER FUNCTION COMPARE_FACES(INDEX1,INDEX2)
INTEGER, INTENT(IN) :: INDEX1, INDEX2
INTEGER, POINTER, DIMENSION(:) :: FACE1, FACE2
INTEGER :: F1(3), F2(3)

FACE1=>FACES(3*INDEX1-2:3*INDEX1)
FACE2=>FACES(3*INDEX2-2:3*INDEX2)
F1(1:3) = (/FACE1(1),MIN(FACE1(2),FACE1(3)),MAX(FACE1(2),FACE1(3))/)
F2(1:3) = (/FACE2(1),MIN(FACE2(2),FACE2(3)),MAX(FACE2(2),FACE2(3))/)

COMPARE_FACES=0
IF (F1(1)<F2(1)) THEN
   COMPARE_FACES=1
ELSE IF (F1(1)>F2(1)) THEN
   COMPARE_FACES=-1
ENDIF
IF (COMPARE_FACES/=0) RETURN

IF (F1(2)<F2(2)) THEN
   COMPARE_FACES=1
ELSE IF (F1(2)>F2(2)) THEN
   COMPARE_FACES=-1
ENDIF
IF (COMPARE_FACES/=0) RETURN

IF (F1(3)<F2(3)) THEN
   COMPARE_FACES=1
ELSE IF (F1(3)>F2(3)) THEN
   COMPARE_FACES=-1
ENDIF
END FUNCTION COMPARE_FACES

END SUBROUTINE READ_GEOM

! ---------------------------- GENERATE_CUTCELLS ----------------------------------------

SUBROUTINE GENERATE_CUTCELLS
USE BOXTETRA_ROUTINES, ONLY: GET_TETRABOX_VOLUME

! preliminary routine to classify type of cell (cut, solid or gas)

TYPE (MESH_TYPE), POINTER :: M
INTEGER :: I, J, K, IV
REAL(EB) :: XB(6)
REAL(EB), POINTER, DIMENSION(:) :: X, Y, Z
REAL(EB) :: TETBOX_VOLUME, BOX_VOLUME
REAL(EB) :: INTERSECTION_VOLUME
REAL(EB), POINTER, DIMENSION(:) :: V0, V1, V2, V3
INTEGER :: VINDEX, N_CUTCELLS, N_SOLIDCELLS, N_GASCELLS, N_TOTALCELLS
INTEGER :: IZERO
INTEGER, PARAMETER :: SOLID=0, GAS=1, CUTCELL=2
INTEGER :: NX, NXY, IJK
REAL(EB) :: AREAS(6), CENTROID(3)

M=>MESHES(1) ! for now, only deal with a single mesh case
X(0:M%IBAR)=>M%X(0:IBAR)
Y(0:M%JBAR)=>M%Y(0:JBAR)
Z(0:M%KBAR)=>M%Z(0:KBAR)

IF (.NOT.ALLOCATED(M%CUTCELL_LIST)) THEN
   ALLOCATE(M%CUTCELL_LIST(0:M%IBAR*M%JBAR*M%KBAR),STAT=IZERO)
   CALL ChkMemErr('GENERATE_CUTCELLS','CUTCELL_LIST',IZERO)
ENDIF   

N_CUTCELLS=0
N_SOLIDCELLS=0
N_GASCELLS=0
N_TOTALCELLS=M%IBAR*M%JBAR*M%KBAR
NX = M%IBAR
NXY = M%IBAR*M%JBAR
DO K = 0, M%KBAR - 1
   XB(5:6) = (/Z(K),Z(K+1)/)
   DO J = 0, M%JBAR - 1
      XB(3:4) = (/Y(J),Y(J+1)/)
      DO I = 0, M%IBAR - 1
         XB(1:2) = (/X(I),X(I+1)/)
         BOX_VOLUME = (XB(6)-XB(5))*(XB(4)-XB(3))*(XB(2)-XB(1))

         INTERSECTION_VOLUME=0.0_EB
         DO IV=1,N_VOLU
            VINDEX=VOLUME(IV)%VERTEX(1)
            V0(1:3)=>VERTEX(VINDEX)%XYZ(1:3)
            VINDEX=VOLUME(IV)%VERTEX(2)
            V1(1:3)=>VERTEX(VINDEX)%XYZ(1:3)
            VINDEX=VOLUME(IV)%VERTEX(3)
            V2(1:3)=>VERTEX(VINDEX)%XYZ(1:3)
            VINDEX=VOLUME(IV)%VERTEX(4)
            V3(1:3)=>VERTEX(VINDEX)%XYZ(1:3)
            CALL GET_TETRABOX_VOLUME(XB,V3,V0,V1,V2,TETBOX_VOLUME,AREAS,CENTROID)
            INTERSECTION_VOLUME = INTERSECTION_VOLUME + TETBOX_VOLUME
         ENDDO
         IJK = K*NXY + J*NX + I
         IF ( INTERSECTION_VOLUME <= 0.0001_EB*BOX_VOLUME ) THEN 
            N_GASCELLS=N_GASCELLS+1
         ELSEIF (ABS(BOX_VOLUME-INTERSECTION_VOLUME) <= 0.0001_EB*BOX_VOLUME ) THEN
            N_SOLIDCELLS = N_SOLIDCELLS + 1
         ELSE
            M%CUTCELL_LIST(N_CUTCELLS) = IJK
            N_CUTCELLS = N_CUTCELLS + 1
         ENDIF
         
      ENDDO
   ENDDO
ENDDO
M%N_CUTCELLS = N_CUTCELLS

END SUBROUTINE GENERATE_CUTCELLS

! ---------------------------- INIT_SPHERE ----------------------------------------

SUBROUTINE INIT_SPHERE(N_LEVELS,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)
USE MATH_FUNCTIONS, ONLY: NORM2

INTEGER, INTENT(IN) :: N_LEVELS
INTEGER, INTENT(OUT) :: N_VERTS, N_FACES
INTEGER, INTENT(IN) :: MAX_VERTS, MAX_FACES
REAL(EB), TARGET, INTENT(OUT) :: SPHERE_VERTS(3*MAX_VERTS)
INTEGER, TARGET, INTENT(OUT) :: SPHERE_FACES(3*MAX_FACES)

REAL(EB) :: ARG
REAL(EB), DIMENSION(3) :: VERT
INTEGER :: I,IFACE
INTEGER, DIMENSION(60) :: FACE_LIST
REAL(EB), PARAMETER :: ONETHIRD=1.0_EB/3.0_EB, TWOTHIRDS=2.0_EB/3.0_EB

DATA (FACE_LIST(I),I=1,60) / &
   1, 2, 3,  1, 3, 4,  1, 4, 5,  1, 5, 6,  1, 6,2, &
   2, 7, 3,  3, 7, 8,  3, 8, 4,  4, 8, 9,  4, 9,5, &
   5, 9,10,  5,10, 6,  6,10,11,  6,11, 2,  2,11,7, &
   12, 8,7,  12, 9,8,  12,10,9, 12,11,10, 12,7,11  &
   /

N_VERTS = 12
N_FACES = 20

SPHERE_VERTS(1:3) = (/0.0,0.0,1.0/) ! 1 
DO I=2, 6
   ARG = REAL(I-2,EB)*72.0_EB
   ARG = 2.0_EB*PI*ARG/360.0_EB
   VERT = (/COS(ARG),SIN(ARG),1.0_EB/SQRT(5.0_EB)/) 
   SPHERE_VERTS(3*I-2:3*I) = VERT/NORM2(VERT)  ! 2-6
ENDDO
DO I=7, 11
   ARG = 36.0_EB+REAL(I-7,EB)*72.0_EB
   ARG = 2.0_EB*PI*ARG/360.0_EB
   VERT = (/COS(ARG),SIN(ARG),-1.0_EB/SQRT(5.0_EB)/) 
   SPHERE_VERTS(3*I-2:3*I) = VERT/NORM2(VERT)  ! 7-11
ENDDO
SPHERE_VERTS(34:36) = (/0.0,0.0,-1.0/) ! 12

SPHERE_FACES(1:60) = FACE_LIST(1:60)

! refine each triangle of the icosahedron recursively until the
! refined triangle sides are the same size as the grid mesh

DO IFACE = 1, 20 ! can't use N_FACES since N_FACES is altered by each call to REFINE_FACE
   CALL REFINE_FACE(N_LEVELS,IFACE,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)
ENDDO
END SUBROUTINE INIT_SPHERE

! ---------------------------- COMPUTE_TEXTURES ----------------------------------------

SUBROUTINE COMPUTE_TEXTURES(SPHERE_VERTS,SPHERE_FACES,SPHERE_TFACES,MAX_VERTS,MAX_FACES,N_FACES)
INTEGER, INTENT(IN) :: N_FACES,MAX_VERTS,MAX_FACES
REAL(EB), TARGET, INTENT(IN) :: SPHERE_VERTS(3*MAX_VERTS)
REAL(EB), INTENT(OUT), TARGET :: SPHERE_TFACES(6*MAX_FACES)
INTEGER, TARGET, INTENT(IN) :: SPHERE_FACES(3*MAX_FACES)

INTEGER :: IFACE
REAL(EB) :: EPS_TEXTURE
REAL(EB), POINTER, DIMENSION(:) :: TFACE, VERTPTR
INTEGER, POINTER, DIMENSION(:) :: FACEPTR

EPS_TEXTURE=0.25_EB
IFACE_LOOP: DO IFACE=0, N_FACES-1

   FACEPTR=>SPHERE_FACES(3*IFACE+1:3*IFACE+3)
   TFACE=>SPHERE_TFACES(6*IFACE+1:6*IFACE+6)
     
   VERTPTR=>SPHERE_VERTS(3*FACEPTR(1)-2:3*FACEPTR(1))
   CALL COMPUTE_TEXTURE(VERTPTR(1:3),TFACE(1:2))
   
   VERTPTR=>SPHERE_VERTS(3*FACEPTR(2)-2:3*FACEPTR(2))
   CALL COMPUTE_TEXTURE(VERTPTR(1:3),TFACE(3:4))
   
   VERTPTR=>SPHERE_VERTS(3*FACEPTR(3)-2:3*FACEPTR(3))
   CALL COMPUTE_TEXTURE(VERTPTR(1:3),TFACE(5:6))

   ! adjust texture coordinates when a triangle crosses the "prime meridian"

   IF (TFACE(1)>1.0_EB-EPS_TEXTURE .AND. TFACE(3)<EPS_TEXTURE) THEN
      TFACE(3)=TFACE(3)+1.0_EB
   ENDIF
   IF (TFACE(1)>1.0_EB-EPS_TEXTURE .AND. TFACE(5)<EPS_TEXTURE) THEN
      TFACE(5)=TFACE(5)+1.0_EB
   ENDIF
   
   IF (TFACE(3)>1.0_EB-EPS_TEXTURE .AND. TFACE(1)<EPS_TEXTURE) THEN
      TFACE(1)=TFACE(1)+1.0_EB
   ENDIF
   IF (TFACE(3)>1.0_EB-EPS_TEXTURE .AND. TFACE(5)<EPS_TEXTURE) THEN
      TFACE(5)=TFACE(5)+1.0_EB
   ENDIF
   
   IF (TFACE(5)>1.0_EB-EPS_TEXTURE .AND. TFACE(1)<EPS_TEXTURE) THEN
      TFACE(1)=TFACE(1)+1.0_EB
   ENDIF
   IF (TFACE(5)>1.0_EB-EPS_TEXTURE .AND. TFACE(3)<EPS_TEXTURE) THEN
      TFACE(3)=TFACE(3)+1.0_EB
   ENDIF
   
   ! make adjustments when face is at a pole
   
   IF (ABS(TFACE(2)-1.0_EB)<0.001_EB) THEN
      TFACE(1) = (TFACE(3)+TFACE(5))/2.0_EB
   ENDIF
   IF (ABS(TFACE(4)-1.0_EB)<0.001_EB) THEN
      TFACE(3) = (TFACE(1)+TFACE(5))/2.0_EB
   ENDIF
   IF (ABS(TFACE(6)-1.0_EB)<0.001_EB) THEN
      TFACE(5) = (TFACE(1)+TFACE(3))/2.0_EB
   ENDIF
   
   IF (ABS(TFACE(2))<0.001_EB) THEN
      TFACE(1) = (TFACE(3)+TFACE(5))/2.0_EB
   ENDIF
   IF (ABS(TFACE(4))<0.001_EB) THEN
      TFACE(3) = (TFACE(1)+TFACE(5))/2.0_EB
   ENDIF
   IF (ABS(TFACE(6))<0.001_EB) THEN
      TFACE(5) = (TFACE(1)+TFACE(3))/2.0_EB
   ENDIF
  
ENDDO IFACE_LOOP
END SUBROUTINE COMPUTE_TEXTURES

! ---------------------------- INIT_SPHERE2 ----------------------------------------

SUBROUTINE INIT_SPHERE2(N_VERTS, N_FACES, NLAT,NLONG,SPHERE_VERTS,SPHERE_FACES)
INTEGER, INTENT(IN) :: NLAT, NLONG
REAL(EB), INTENT(OUT), TARGET, DIMENSION(3*(NLONG*(NLAT-2) + 2)) :: SPHERE_VERTS
INTEGER, INTENT(OUT), TARGET, DIMENSION(3*(NLAT-1)*NLONG*2*2) :: SPHERE_FACES
INTEGER, INTENT(OUT) :: N_VERTS, N_FACES
REAL(EB) :: LAT, LONG
INTEGER :: ILONG, ILAT
REAL(EB) :: COSLAT(NLAT), SINLAT(NLAT)
REAL(EB) :: COSLONG(NLONG), SINLONG(NLONG)

INTEGER :: I , J, IJ, I11, I12, I21, I22

N_VERTS = NLONG*(NLAT-2) + 2
N_FACES = (NLAT-2)*NLONG*2

IJ = 0
DO I = 1, NLAT
   LAT = PI/2.0_EB - PI*REAL(I-1,EB)/REAL(NLAT-1,EB)
   COSLAT(I) = COS(LAT)
   SINLAT(I) = SIN(LAT)
ENDDO
DO I = 1, NLONG 
   LONG = -PI + 2.0_EB*PI*REAL(I-1,EB)/REAL(NLONG,EB)
   COSLONG(I) = COS(LONG)
   SINLONG(I) = SIN(LONG)
ENDDO

! define vertices

! north pole

SPHERE_VERTS(1:3)  = (/0.0_EB,0.0_EB,1.0_EB/)

! middle latitudes

IJ = 4
DO I = 2, NLAT-1
   DO J = 1, NLONG
      SPHERE_VERTS(IJ:IJ+2)   = (/COSLONG(J)*COSLAT(I),SINLONG(J)*COSLAT(I),SINLAT(I)/)
      IJ = IJ + 3
   ENDDO
ENDDO

! south pole

SPHERE_VERTS(IJ:IJ+2)  = (/0.0_EB,0.0_EB,-1.0_EB/)

! define faces

! faces connected to north pole
IJ=1
DO ILONG = 1, NLONG
   I11 = ILONG+1
   I12 = ILONG+2
   I22 = 1
   IF (ILONG==NLONG)I12=2
   SPHERE_FACES(IJ:IJ+2)   = (/I22, I11,I12/)
   IJ = IJ + 3
ENDDO

DO ILAT = 2, NLAT - 2
   DO ILONG = 1, NLONG
   
      I11 = 1+ILONG+NLONG*(ILAT+1-2)
      I21 = I11 + 1
      I12 = 1+ILONG+NLONG*(ILAT-2)
      I22 = I12 + 1
      IF ( ILONG==NLONG) THEN
         I21 = 1+1+NLONG*(ILAT+1-2)
         I22 = 1+1+NLONG*(ILAT-2)
      ENDIF

      SPHERE_FACES(IJ:IJ+2)   = (/I12,I11,I22/)
      SPHERE_FACES(IJ+3:IJ+5) = (/I22,I11,I21/)
      IJ = IJ + 6
   ENDDO
ENDDO

! faces connected to south pole

DO ILONG = 1, NLONG
   I11 = ILONG+1 + NLONG*(NLAT-3)
   I12 = I11 + 1
   I22 = NLONG*(NLAT-2)+2
   IF (ILONG==NLONG) I12=2+NLONG*(NLAT-3)
   SPHERE_FACES(IJ:IJ+2)   = (/I11,I22,I12/)
   IJ = IJ + 3
ENDDO
END SUBROUTINE INIT_SPHERE2

! ---------------------------- REFINE_FACE ----------------------------------------

RECURSIVE SUBROUTINE REFINE_FACE(N_LEVELS,IFACE,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)
USE MATH_FUNCTIONS, ONLY: NORM2

INTEGER, INTENT(IN) :: N_LEVELS
INTEGER, INTENT(IN) :: IFACE
INTEGER, INTENT(INOUT) :: N_VERTS, N_FACES
INTEGER, INTENT(IN) :: MAX_VERTS, MAX_FACES
REAL(EB), INTENT(INOUT), TARGET :: SPHERE_VERTS(3*MAX_VERTS)
INTEGER, INTENT(INOUT), TARGET :: SPHERE_FACES(3*MAX_FACES)

INTEGER, POINTER, DIMENSION(:) :: FACE1, FACE2, FACE3, FACE4
REAL(EB), POINTER, DIMENSION(:) :: V1, V2, V3
REAL(EB), POINTER, DIMENSION(:) :: V12, V13, V23
INTEGER :: N1, N2, N3, N4

IF (N_LEVELS==0 .OR. N_FACES+3>MAX_FACES .OR. N_VERTS+3>MAX_VERTS) RETURN ! prevent memory overwrites

FACE1(1:3)=>SPHERE_FACES(3*IFACE-2:3*IFACE) ! original face and 1st new face
FACE2(1:3)=>SPHERE_FACES(3*N_FACES+1:3*N_FACES+3) ! 2nd new face
FACE3(1:3)=>SPHERE_FACES(3*N_FACES+4:3*N_FACES+6) ! 3rd new face
FACE4(1:3)=>SPHERE_FACES(3*N_FACES+7:3*N_FACES+9) ! 4th new face

V1(1:3)=>SPHERE_VERTS(3*FACE1(1)-2:3*FACE1(1)) ! FACE1(1)
V2(1:3)=>SPHERE_VERTS(3*FACE1(2)-2:3*FACE1(2)) ! FACE1(2)
V3(1:3)=>SPHERE_VERTS(3*FACE1(3)-2:3*FACE1(3)) ! FACE1(3)

V12(1:3)=>SPHERE_VERTS(3*N_VERTS+1:3*N_VERTS+3)
V13(1:3)=>SPHERE_VERTS(3*N_VERTS+4:3*N_VERTS+6)
V23(1:3)=>SPHERE_VERTS(3*N_VERTS+7:3*N_VERTS+9)

V12 = (V1+V2)/2.0_EB
V13 = (V1+V3)/2.0_EB
V23 = (V2+V3)/2.0_EB
V12 = V12/NORM2(V12) ! N_VERTS + 1
V13 = V13/NORM2(V13) ! N_VERTS + 2
V23 = V23/NORM2(V23) ! N_VERTS + 3

! split triangle 123 into 4 triangles

!         1
!       /F1\                          .
!     12----13                     
!    /F2\F3/F4\                       i.
!  2 --- 23----3 

FACE2(1:3) = (/N_VERTS+1,FACE1(2),N_VERTS+3/)
FACE3(1:3) = (/N_VERTS+1,N_VERTS+3,N_VERTS+2/)
FACE4(1:3) = (/N_VERTS+2,N_VERTS+3,FACE1(3)/)
FACE1(1:3) = (/ FACE1(1),N_VERTS+1,N_VERTS+2/)

N1 = IFACE
N2 = N_FACES+1
N3 = N_FACES+2
N4 = N_FACES+3

N_FACES = N_FACES + 3
N_VERTS = N_VERTS + 3
IF (N_LEVELS==1) RETURN  ! stop recursion

CALL REFINE_FACE(N_LEVELS-1,N1,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)
CALL REFINE_FACE(N_LEVELS-1,N2,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)
CALL REFINE_FACE(N_LEVELS-1,N3,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)
CALL REFINE_FACE(N_LEVELS-1,N4,N_VERTS,N_FACES,MAX_VERTS,MAX_FACES,SPHERE_VERTS,SPHERE_FACES)

END SUBROUTINE REFINE_FACE

! ---------------------------- COMPUTE_TEXTURE ----------------------------------------

SUBROUTINE COMPUTE_TEXTURE(XYZ,TEXT_COORDS)
USE MATH_FUNCTIONS, ONLY: NORM2
REAL(EB), INTENT(IN), DIMENSION(3) :: XYZ
REAL(EB), INTENT(OUT), DIMENSION(2) :: TEXT_COORDS
REAL(EB), DIMENSION(2) :: ANGLES
REAL(EB) :: NORM2_XYZ, Z_ANGLE

NORM2_XYZ = NORM2(XYZ)
IF (NORM2_XYZ < TWO_EPSILON_EB) THEN
   Z_ANGLE = 0.0_EB
ELSE
   Z_ANGLE = ASIN(XYZ(3)/NORM2_XYZ)
ENDIF
ANGLES = (/ATAN2(XYZ(2),XYZ(1)),Z_ANGLE/)

!convert back to texture coordinates
TEXT_COORDS = (/ 0.5_EB + 0.5_EB*ANGLES(1)/PI,0.5_EB + ANGLES(2)/PI /)
END SUBROUTINE COMPUTE_TEXTURE

! ---------------------------- GET_GEOM_ID ----------------------------------------

INTEGER FUNCTION GET_GEOM_ID(ID,N_LAST)

! return the index of the geometry array with label ID

CHARACTER(30), INTENT(IN) :: ID
INTEGER, INTENT(IN) :: N_LAST

INTEGER :: N
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
   
GET_GEOM_ID = 0
DO N=1,N_LAST
   G=>GEOMETRY(N)
   IF (TRIM(G%ID)==TRIM(ID)) THEN
      GET_GEOM_ID = N
      RETURN
   ENDIF
ENDDO
END FUNCTION GET_GEOM_ID

! ---------------------------- GET_MATL_INDEX ----------------------------------------

INTEGER FUNCTION GET_MATL_INDEX(ID)
CHARACTER(30), INTENT(IN) :: ID
INTEGER :: N

DO N = 1, N_MATL
   IF (TRIM(MATERIAL(N)%ID)/=TRIM(ID)) CYCLE
   GET_MATL_INDEX = N
   RETURN
ENDDO
GET_MATL_INDEX = 0
END FUNCTION GET_MATL_INDEX

! ---------------------------- GET_SURF_INDEX ----------------------------------------

INTEGER FUNCTION GET_SURF_INDEX(ID)
CHARACTER(30), INTENT(IN) :: ID
INTEGER :: N

DO N = 1, N_SURF
   IF (TRIM(SURFACE(N)%ID)/=TRIM(ID)) CYCLE
   GET_SURF_INDEX = N
   RETURN
ENDDO
GET_SURF_INDEX = 0
END FUNCTION GET_SURF_INDEX

! ---------------------------- SETUP_TRANSFORM ----------------------------------------

SUBROUTINE SETUP_TRANSFORM(SCALE,AZ,ELEV,GAXIS,GROTATE,M)

! construct a rotation matrix M that rotates a vector by
! AZ degrees around the Z axis then ELEV degrees around
! the (cos AZ, sin AZ, 0) axis

REAL(EB), INTENT(IN) :: SCALE(3), AZ, ELEV, GAXIS(3), GROTATE
REAL(EB), DIMENSION(3,3), INTENT(OUT) :: M

REAL(EB) :: AXIS(3), M0(3,3), M1(3,3), M2(3,3), M3(3,3), MTEMP(3,3), MTEMP2(3,3)

M0 = RESHAPE ((/&
               SCALE(1),  0.0_EB, 0.0_EB,&
                 0.0_EB,SCALE(2), 0.0_EB,&
                 0.0_EB,  0.0_EB,SCALE(3) &
               /),(/3,3/))

AXIS = (/0.0_EB, 0.0_EB, 1.0_EB/)
CALL SETUP_ROTATE(AZ,AXIS,M1)

AXIS = (/COS(DEG2RAD*AZ), SIN(DEG2RAD*AZ), 0.0_EB/)
CALL SETUP_ROTATE(ELEV,AXIS,M2)

CALL SETUP_ROTATE(GROTATE,GAXIS,M3)

MTEMP = MATMUL(M1,M0)
MTEMP2 = MATMUL(M2,MTEMP)
M = MATMUL(M3,MTEMP2)

END SUBROUTINE SETUP_TRANSFORM

! ---------------------------- SETUP_ROTATE ----------------------------------------

SUBROUTINE SETUP_ROTATE(ALPHA,U,M)

! construct a rotation matrix M that rotates a vector by
! ALPHA degrees about an axis U

REAL(EB), INTENT(IN) :: ALPHA, U(3)
REAL(EB), INTENT(OUT) :: M(3,3)

REAL(EB) :: UP(3,1), S(3,3), UUT(3,3), IDENTITY(3,3)

UP = RESHAPE(U/SQRT(DOT_PRODUCT(U,U)),(/3,1/))
S =   RESHAPE( (/&
                   0.0_EB, -UP(3,1),  UP(2,1),&
                  UP(3,1),   0.0_EB, -UP(1,1),&
                 -UP(2,1),  UP(1,1),  0.0_EB  &
                 /),(/3,3/))
UUT = MATMUL(UP,TRANSPOSE(UP))
IDENTITY = RESHAPE ((/&
               1.0_EB,0.0_EB,0.0_EB,&
               0.0_EB,1.0_EB,0.0_EB,&
               0.0_EB,0.0_EB,1.0_EB &
               /),(/3,3/))
M = UUT + COS(ALPHA*DEG2RAD)*(IDENTITY - UUT) + SIN(ALPHA*DEG2RAD)*S

END SUBROUTINE SETUP_ROTATE

! ---------------------------- TRANSLATE_VEC ----------------------------------------

SUBROUTINE TRANSLATE_VEC(XYZ,N,XIN,XOUT)

! translate a geometry by the vector XYZ

INTEGER, INTENT(IN) :: N
REAL(EB), INTENT(IN) :: XYZ(3), XIN(3*N)
REAL(EB), INTENT(OUT) :: XOUT(3*N)

REAL(EB) :: VEC(3)
INTEGER :: I

DO I = 1, N 
   VEC(1:3) = XYZ(1:3) + XIN(3*I-2:3*I) ! copy into a temp array so XIN and XOUT can point to same space
   XOUT(3*I-2:3*I) = VEC(1:3)
ENDDO

END SUBROUTINE TRANSLATE_VEC

! ---------------------------- ROTATE_VEC ----------------------------------------

SUBROUTINE ROTATE_VEC(M,N,XYZ0,XIN,XOUT)

! rotate the vector XIN about the origin XYZ0

INTEGER, INTENT(IN) :: N
REAL(EB), INTENT(IN) :: M(3,3), XIN(3*N), XYZ0(3)
REAL(EB), INTENT(OUT) :: XOUT(3*N)

REAL(EB) :: VEC(3)
INTEGER :: I

DO I = 1, N
   VEC(1:3) = MATMUL(M,XIN(3*I-2:3*I)-XYZ0(1:3))  ! copy into a temp array so XIN and XOUT can point to same space
   XOUT(3*I-2:3*I) = VEC(1:3) + XYZ0(1:3)
ENDDO
END SUBROUTINE ROTATE_VEC

! ---------------------------- PROCESS_GEOM ----------------------------------------

SUBROUTINE PROCESS_GEOM(IS_DYNAMIC,TIME, N_VERTS, N_FACES, N_VOLUS)

! transform (scale, rotate and translate) vectors found on each &GEOM line

   LOGICAL, INTENT(IN) :: IS_DYNAMIC
   REAL(EB), INTENT(IN) :: TIME
   INTEGER, INTENT(OUT) :: N_VERTS, N_FACES, N_VOLUS
   
   INTEGER :: I
   TYPE(GEOMETRY_TYPE), POINTER :: G
   REAL(EB) :: M(3,3), DELTA_T
   
   IF (IS_DYNAMIC) THEN
      DELTA_T = TIME - T_BEGIN
   ELSE
      DELTA_T = 0.0_EB
   ENDIF
   
   DO I = 1, N_GEOMETRY
      G=>GEOMETRY(I)
      
      G%SCALE = G%SCALE_BASE + DELTA_T*G%SCALE_DOT
      G%AZIM = G%AZIM_BASE + DELTA_T*G%AZIM_DOT
      G%ELEV = G%ELEV_BASE + DELTA_T*G%ELEV_DOT
      G%XYZ = G%XYZ_BASE + DELTA_T*G%XYZ_DOT
      G%GROTATE = G%GROTATE_BASE + DELTA_T*G%GROTATE_DOT
      
      IF (IS_DYNAMIC .AND. G%IS_DYNAMIC .OR. .NOT.IS_DYNAMIC .AND. .NOT.G%IS_DYNAMIC) THEN
         G%N_VERTS = G%N_VERTS_BASE
         G%N_FACES = G%N_FACES_BASE
         G%N_VOLUS = G%N_VOLUS_BASE
      ENDIF
   ENDDO

   DO I = 1, N_GEOMETRY
      G=>GEOMETRY(I)

      IF (G%NSUB_GEOMS>0) CALL EXPAND_GROUPS(I) ! create vertex and face list from geometries specified in GEOM_IDS list
      IF (G%IS_DYNAMIC .AND. .NOT.IS_DYNAMIC) CYCLE
      IF (.NOT.G%IS_DYNAMIC .AND. IS_DYNAMIC) CYCLE
      IF (TRIM(G%GEOC_FILENAME)=='null' .OR. ABS(TIME-T_BEGIN)<TWO_EPSILON_EB) THEN
         CALL SETUP_TRANSFORM(G%SCALE,G%AZIM,G%ELEV,G%GAXIS,G%GROTATE,M)
         CALL ROTATE_VEC(M,G%N_VERTS,G%XYZ0,G%VERTS_BASE,G%VERTS)
         CALL TRANSLATE_VEC(G%XYZ,G%N_VERTS,G%VERTS,G%VERTS)
      ENDIF
   ENDDO
   CALL GEOM2TEXTURE
   
   N_VERTS = 0
   N_FACES = 0
   N_VOLUS = 0
   DO I = 1, N_GEOMETRY ! count vertices and faces
      G=>GEOMETRY(I)
      
      IF (G%COMPONENT_ONLY) CYCLE
      IF (G%IS_DYNAMIC .AND. .NOT.IS_DYNAMIC) CYCLE
      IF (.NOT.G%IS_DYNAMIC .AND. IS_DYNAMIC) CYCLE
      N_VERTS = N_VERTS + G%N_VERTS
      N_FACES = N_FACES + G%N_FACES
      N_VOLUS = N_VOLUS + G%N_VOLUS
   ENDDO
   

END SUBROUTINE PROCESS_GEOM

! ---------------------------- GEOM2TEXTURE ----------------------------------------

SUBROUTINE GEOM2TEXTURE
   INTEGER :: I,J,K,JJ
   TYPE(GEOMETRY_TYPE), POINTER :: G
   REAL(EB), POINTER, DIMENSION(:) :: XYZ, TFACES
   INTEGER, POINTER, DIMENSION(:) :: FACES
   INTEGER :: SURF_INDEX
   TYPE(SURFACE_TYPE), POINTER :: SF=>NULL()
   
   DO I = 1, N_GEOMETRY
      G=>GEOMETRY(I)
      
      IF (G%NSUB_GEOMS/=0 .OR. G%TEXTURE_MAPPING/='RECTANGULAR') CYCLE
      DO J = 0, G%N_FACES-1
         SURF_INDEX = G%SURFS(1+J)
         SF=>SURFACE(SURF_INDEX)
         IF (TRIM(SF%TEXTURE_MAP)=='null') CYCLE
         FACES(1:3)=>G%FACES(1+3*J:3+3*J)
         TFACES(1:6)=>G%TFACES(1+6*J:6+6*J)
         DO K = 0, 2
            JJ = FACES(1+K)
            
            XYZ(1:3) => G%VERTS(3*JJ-2:3*JJ)
            TFACES(1+2*K:2+2*K) = (XYZ(1:2) - G%TEXTURE_ORIGIN(1:2))/G%TEXTURE_SCALE(1:2)
         ENDDO
      ENDDO
   ENDDO
END SUBROUTINE GEOM2TEXTURE

! ---------------------------- MERGE_GEOMS ----------------------------------------

SUBROUTINE MERGE_GEOMS(VERTS,N_VERTS,FACES,TFACES,SURF_IDS,N_FACES,VOLUS,MATL_IDS,N_VOLUS,IS_DYNAMIC)

! combine vectors and faces found on all &GEOM lines into one set of VECTOR and FACE arrays

INTEGER, INTENT(IN) :: N_VERTS, N_FACES, N_VOLUS
LOGICAL, INTENT(IN) :: IS_DYNAMIC
REAL(EB), DIMENSION(:), INTENT(OUT) :: VERTS(3*N_VERTS), TFACES(6*N_FACES)
INTEGER, DIMENSION(:), INTENT(OUT) :: FACES(3*N_FACES), VOLUS(4*N_VOLUS), MATL_IDS(N_VOLUS), SURF_IDS(N_FACES)

INTEGER :: I
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
INTEGER :: IVERT, ITFACE, IFACE, IVOLUS, IMATL, ISURF, OFFSET
   
IVERT = 0
ITFACE = 0
IFACE = 0
IVOLUS = 0
ISURF = 0
IMATL = 0
OFFSET = 0
DO I = 1, N_GEOMETRY
   G=>GEOMETRY(I)

   IF (G%IS_DYNAMIC .AND. .NOT.IS_DYNAMIC) CYCLE
   IF (.NOT.G%IS_DYNAMIC .AND. IS_DYNAMIC) CYCLE

   IF (G%COMPONENT_ONLY) CYCLE
   
   IF (G%N_VERTS>0) THEN
      VERTS(1+IVERT:3*G%N_VERTS+IVERT) = G%VERTS(1:3*G%N_VERTS)
      IVERT = IVERT + 3*G%N_VERTS
   ENDIF
   IF (G%N_FACES>0) THEN
      FACES(1+IFACE:3*G%N_FACES + IFACE) = G%FACES(1:3*G%N_FACES)+OFFSET
      IFACE = IFACE + 3*G%N_FACES

      TFACES(1+ITFACE:6*G%N_FACES + ITFACE) = G%TFACES(1:6*G%N_FACES)
      ITFACE = ITFACE + 6*G%N_FACES

      SURF_IDS(1+ISURF:G%N_FACES+ISURF) = G%SURFS(1:G%N_FACES)
      ISURF = ISURF +   G%N_FACES
   ENDIF
   IF (G%N_VOLUS>0) THEN
      VOLUS(1+IVOLUS:4*G%N_VOLUS + IVOLUS) = G%VOLUS(1:4*G%N_VOLUS)+OFFSET
      IVOLUS = IVOLUS + 4*G%N_VOLUS

      MATL_IDS(1+IMATL:G%N_VOLUS+IMATL) = G%MATLS(1:G%N_VOLUS)
      IMATL = IMATL + G%N_VOLUS
   ENDIF
   OFFSET = OFFSET + G%N_VERTS
ENDDO

END SUBROUTINE MERGE_GEOMS

! ---------------------------- EXPAND_GROUPS ----------------------------------------

SUBROUTINE EXPAND_GROUPS(IGEOM)

! for each geometry specifed in a &GEOM line, merge geometries referenced
! by GEOM_IDS after scaling, rotating and translating

INTEGER, INTENT(IN) :: IGEOM

INTEGER :: IVERT, IFACE, IVOLUS, J, NSUB_VERTS, NSUB_FACES, NSUB_VOLUS
INTEGER, POINTER, DIMENSION(:) :: FIN,FOUT, SURFIN, SURFOUT, MATLIN, MATLOUT
REAL(EB) :: M(3,3)
REAL(EB), POINTER, DIMENSION(:) :: XIN, XOUT, TFIN, TFOUT
REAL(EB), DIMENSION(:), POINTER :: DSCALEPTR, DXYZ0PTR, DXYZPTR
TYPE(GEOMETRY_TYPE), POINTER :: G, GSUB=>NULL()
REAL(EB), DIMENSION(3,3) :: GIDENTITY
REAL(EB) :: GZERO=0.0_EB


IF (IGEOM<=1) RETURN   
G=>GEOMETRY(IGEOM)
     
IF (G%NSUB_GEOMS==0) RETURN
      
IF (G%N_VERTS_BASE==0.OR.(G%N_FACES_BASE==0 .AND. G%N_VOLUS_BASE==0)) RETURN ! nothing to do if GEOM_IDS geometries are empty

GIDENTITY = RESHAPE ((/&
               1.0_EB,0.0_EB,0.0_EB,&
               0.0_EB,1.0_EB,0.0_EB,&
               0.0_EB,0.0_EB,1.0_EB &
               /),(/3,3/))

IVERT = 0
IFACE = 0
IVOLUS = 0
DO J = 1, G%NSUB_GEOMS
   GSUB=>GEOMETRY(G%SUB_GEOMS(J))
   NSUB_VERTS = GSUB%N_VERTS_BASE
   NSUB_FACES = GSUB%N_FACES_BASE
   NSUB_VOLUS = GSUB%N_VOLUS_BASE
        
   IF (NSUB_VERTS==0 .OR. (NSUB_FACES==0 .AND. NSUB_VOLUS==0)) CYCLE

   DSCALEPTR(1:3) => G%DSCALE(1:3,J)
   CALL SETUP_TRANSFORM(DSCALEPTR,G%DAZIM(J),G%DELEV(J),GIDENTITY,GZERO,M)
     
   XIN(1:3*NSUB_VERTS) => GSUB%VERTS(1:3*NSUB_VERTS)
   XOUT(1:3*NSUB_VERTS) => G%VERTS_BASE(1+3*IVERT:3*(IVERT+NSUB_VERTS))
        
   DXYZ0PTR(1:3) => G%DXYZ0(1:3,J)
   DXYZPTR(1:3) => G%DXYZ(1:3,J)
   CALL ROTATE_VEC(M,NSUB_VERTS,DXYZ0PTR,XIN,XOUT)
   CALL TRANSLATE_VEC(DXYZPTR,NSUB_VERTS,XOUT,XOUT)
        
   ! copy and offset face indices

   IF (NSUB_FACES>0) THEN
       FIN(1:3*NSUB_FACES) => GSUB%FACES(1        :3*NSUB_FACES        )
      FOUT(1:3*NSUB_FACES) =>    G%FACES(1+3*IFACE:3*NSUB_FACES+3*IFACE)

      FOUT = FIN + IVERT
      
       TFIN(1:6*NSUB_FACES) => GSUB%TFACES(1        :6*NSUB_FACES        )
      TFOUT(1:6*NSUB_FACES) =>    G%TFACES(1+6*IFACE:6*NSUB_FACES+6*IFACE)

      TFOUT = TFIN

      ! copy surface indices
        
      SURFIN(1:NSUB_FACES) => GSUB%SURFS(1:NSUB_FACES)
      SURFOUT(1:NSUB_FACES) => G%SURFS(1+IFACE:IFACE+NSUB_FACES)
      SURFOUT = SURFIN
   ENDIF

   ! copy and offset volu indices

   IF (NSUB_VOLUS>0) THEN
      FIN(1:4*NSUB_VOLUS) => GSUB%VOLUS(1:4*NSUB_VOLUS)
      FOUT(1:4*NSUB_VOLUS) => G%VOLUS(1+4*IVOLUS:3*(IVOLUS+NSUB_VOLUS))

      FOUT = FIN + IVERT

      ! copy matl indices

      MATLIN(1:NSUB_VOLUS) => GSUB%MATLS(1:NSUB_VOLUS)
      MATLOUT(1:NSUB_VOLUS) => G%MATLS(IVOLUS+1:IVOLUS+NSUB_VOLUS)
      MATLOUT = MATLIN
   ENDIF

   IVERT = IVERT + NSUB_VERTS
   IFACE = IFACE + NSUB_FACES
   IVOLUS = IVOLUS + NSUB_VOLUS
ENDDO
G%N_VERTS = IVERT
G%N_FACES = IFACE
G%N_VOLUS = IVOLUS
IF (IFACE>0 .AND. G%HAVE_SURF) G%SURFS(1:G%N_FACES) = GET_SURF_INDEX(G%SURF_ID)
IF (IVOLUS>0 .AND. G%HAVE_MATL) G%MATLS(1:G%N_VOLUS) = GET_MATL_INDEX(G%MATL_ID)
IF (IVERT>0) G%VERTS(1:3*G%N_VERTS) = G%VERTS_BASE(1:3*G%N_VERTS)

END SUBROUTINE EXPAND_GROUPS

! ---------------------------- CONVERTGEOM ----------------------------------------

SUBROUTINE CONVERTGEOM(TIME)
   REAL(EB), INTENT(IN) :: TIME
   
   INTEGER :: N_VERTS, N_FACES, N_VOLUS
   INTEGER :: N_VERTS_S, N_FACES_S, N_VOLUS_S
   INTEGER :: N_VERTS_D, N_FACES_D, N_VOLUS_D
   INTEGER :: I
   INTEGER, ALLOCATABLE, DIMENSION(:) :: VOLUS, FACES, MATL_IDS, SURF_IDS
   REAL(EB), ALLOCATABLE, DIMENSION(:) :: VERTS, TFACES
   INTEGER :: IZERO
   LOGICAL :: EX
   INTEGER :: NS, NNN
   CHARACTER(MESSAGE_LENGTH) :: MESSAGE
   CHARACTER(60) :: SURFACE_LABEL

   CALL PROCESS_GEOM(.FALSE.,TIME, N_VERTS_S, N_FACES_S, N_VOLUS_S)  ! scale, rotate, translate static GEOM vertices 
   CALL PROCESS_GEOM( .TRUE.,TIME, N_VERTS_D, N_FACES_D, N_VOLUS_D)  ! scale, rotate, translate dynamic GEOM vertices 
   
   N_VERTS = N_VERTS_S + N_VERTS_D
   N_FACES = N_FACES_S + N_FACES_D
   N_VOLUS = N_VOLUS_S + N_VOLUS_D

   ALLOCATE(VERTS(MAX(1,3*N_VERTS)),STAT=IZERO)   ! create arrays to contain all vertices and faces
   CALL ChkMemErr('CONVERTGEOM','VERTS',IZERO)
   
   ALLOCATE(TFACES(MAX(1,6*N_FACES)),STAT=IZERO)   ! create arrays to contain all vertices and faces
   CALL ChkMemErr('CONVERTGEOM','TVERTS',IZERO)

   ALLOCATE(FACES(MAX(1,3*N_FACES)),STAT=IZERO)
   CALL ChkMemErr('CONVERTGEOM','FACES',IZERO)
         
   ALLOCATE(SURF_IDS(MAX(1,N_FACES)),STAT=IZERO)
   CALL ChkMemErr('CONVERTGEOM','SURF_IDS',IZERO)

   ALLOCATE(VOLUS(MAX(1,4*N_VOLUS)),STAT=IZERO)
   CALL ChkMemErr('CONVERTGEOM','VOLUS',IZERO)
         
   ALLOCATE(MATL_IDS(MAX(1,N_VOLUS)),STAT=IZERO)
   CALL ChkMemErr('CONVERTGEOM','MATL_IDS',IZERO)

   IF (N_VERTS_S>0 .AND. (N_FACES_S>0 .OR. N_VOLUS_S>0)) THEN ! merge static geometry
      CALL MERGE_GEOMS(VERTS(1:3*N_VERTS_S),N_VERTS_S,&
         FACES(1:3*N_FACES_S),TFACES(1:3*N_FACES_S),SURF_IDS(1:3*N_FACES_S),N_FACES_S,&
         VOLUS(1:3*N_VOLUS_S),MATL_IDS(1:3*N_VOLUS_S),N_VOLUS_S,.FALSE.)
   ENDIF
   IF (N_VERTS_D>0 .AND. (N_FACES_D>0 .OR. N_VOLUS_D>0)) THEN ! merge dynamic geometry
      CALL MERGE_GEOMS(VERTS(3*N_VERTS_S+1:3*N_VERTS),N_VERTS_D,&
         FACES(3*N_FACES_S+1:3*N_FACES),TFACES(3*N_FACES_S+1:3*N_FACES),SURF_IDS(3*N_FACES_S+1:3*N_FACES),N_FACES_D,&
         VOLUS(3*N_VOLUS_S+1:3*N_VOLUS),MATL_IDS(3*N_VOLUS_S+1:3*N_VOLUS),N_VOLUS_D,.TRUE.)
   ENDIF

! copy geometry info from input data structures to computational data structures
   
   N_VERT = N_VERTS
   IF (N_VERT>0) THEN
      ALLOCATE(VERTEX(N_VERT),STAT=IZERO)
      DO I=1,N_VERT
         VERTEX(I)%X = VERTS(3*I-2)
         VERTEX(I)%Y = VERTS(3*I-1)
         VERTEX(I)%Z = VERTS(3*I)
         VERTEX(I)%XYZ(1:3) = VERTS(3*I-2:3*I)
      ENDDO
   ENDIF

   IF (N_FACES>0) THEN
      N_FACE = N_FACES
      
      ! Allocate FACET array

      IF (ALLOCATED(FACET)) DEALLOCATE(FACET)
      ALLOCATE(FACET(N_FACE),STAT=IZERO)
      CALL ChkMemErr('CONVERTGEOM','FACET',IZERO)

      FACE_LOOP: DO I=1,N_FACE
   
         SURFACE_LABEL = TRIM(SURFACE(SURF_IDS(I))%ID)
         
         ! put in some error checking to make sure face indices are not out of bounds
      
         FACET(I)%VERTEX(1) = FACES(3*I-2) 
         FACET(I)%VERTEX(2) = FACES(3*I-1)
         FACET(I)%VERTEX(3) = FACES(3*I)

         ! Check the SURF_ID against the list of SURF's

         EX = .FALSE.
         DO NS=0,N_SURF
            IF (SURFACE_LABEL==SURFACE(NS)%ID) EX = .TRUE.
         ENDDO
         IF (.NOT.EX) THEN
            WRITE(MESSAGE,'(A,A,A)') 'ERROR: SURF_ID ',SURFACE_LABEL,' not found'
            CALL SHUTDOWN(MESSAGE)
         ENDIF

         ! Assign SURF_INDEX, Index of the Boundary Condition

         FACET(I)%SURF_ID = SURFACE_LABEL
         FACET(I)%SURF_INDEX = DEFAULT_SURF_INDEX
         DO NNN=0,N_SURF
            IF (SURFACE_LABEL==SURFACE(NNN)%ID) FACET(I)%SURF_INDEX = NNN
         ENDDO

         ! Allocate 1D arrays

         IF (.NOT.ALLOCATED(FACET(I)%RHODW)) THEN
            ALLOCATE(FACET(I)%RHODW(N_TRACKED_SPECIES),STAT=IZERO)
            CALL ChkMemErr('CONVERTGEOM','FACET%RHODW',IZERO)
         ENDIF
            
         IF (.NOT.ALLOCATED(FACET(I)%ZZ_F)) THEN
            ALLOCATE(FACET(I)%ZZ_F(N_TRACKED_SPECIES),STAT=IZERO)
            CALL ChkMemErr('CONVERTGEOM','FACET%ZZ_F',IZERO)
         ENDIF

      ENDDO FACE_LOOP

      CALL INIT_FACE
   ENDIF
   
   N_VOLU = N_VOLUS
   IF (N_VOLU>0) THEN
      IF (ALLOCATED(VOLUME)) DEALLOCATE(VOLUME)
      ALLOCATE(VOLUME(N_VOLU),STAT=IZERO)
      CALL ChkMemErr('CONVERTGEOM','VOLUME',IZERO)

      DO I=1,N_VOLU
         VOLUME(I)%VERTEX(1:4) = VOLUS(4*I-3:4*I)
         VOLUME(I)%MATL_ID = TRIM(MATERIAL(MATL_IDS(I))%ID)
      ENDDO
   ENDIF
   
   IF (CUTCELLS) CALL GENERATE_CUTCELLS()

END SUBROUTINE CONVERTGEOM

! ---------------------------- REORDER_FACE ----------------------------------------

SUBROUTINE REORDER_VERTS(VERTS)
! the VERTS triplet V1, V2, V3 defines a face
! reorder V1,V2,V3 so that V1 has the smallest index
INTEGER, INTENT(INOUT) :: VERTS(3)

INTEGER :: VERTS_TEMP(5)

IF ( VERTS(1)<MIN(VERTS(2),VERTS(3))) RETURN ! already in correct order

VERTS_TEMP(1:3) = VERTS(1:3)
VERTS_TEMP(4:5) = VERTS(1:2)

IF (VERTS(2)<MIN(VERTS(1),VERTS(3))) THEN
   VERTS(1:3) = VERTS_TEMP(2:4)
ELSE
   VERTS(1:3) = VERTS_TEMP(3:5)
ENDIF
END SUBROUTINE REORDER_VERTS

! ---------------------------- OUTGEOM ----------------------------------------

SUBROUTINE OUTGEOM(LUNIT,IS_DYNAMIC,TIME)
   INTEGER, INTENT(IN) :: LUNIT
   REAL(EB), INTENT(IN) :: TIME
   LOGICAL, INTENT(IN) :: IS_DYNAMIC
   INTEGER :: N_VERTS, N_FACES, N_VOLUS
   INTEGER :: I
   INTEGER, ALLOCATABLE, DIMENSION(:) :: FACES, VOLUS, MATL_IDS, SURF_IDS
   REAL(EB), ALLOCATABLE, DIMENSION(:) :: VERTS, TFACES
   INTEGER :: IZERO

   CALL PROCESS_GEOM(IS_DYNAMIC,TIME,N_VERTS, N_FACES, N_VOLUS)  ! scale, rotate, translate GEOM vertices 
   
   ALLOCATE(VERTS(MAX(1,3*N_VERTS)),STAT=IZERO)   ! create arrays to contain all vertices and faces
   CALL ChkMemErr('OUTGEOM','VERTS',IZERO)
   
   ALLOCATE(TFACES(MAX(1,6*N_FACES)),STAT=IZERO)
   CALL ChkMemErr('OUTGEOM','VERTS',IZERO)

   ALLOCATE(FACES(MAX(1,3*N_FACES)),STAT=IZERO)
   CALL ChkMemErr('OUTGEOM','FACES',IZERO)

   ALLOCATE(SURF_IDS(MAX(1,N_FACES)),STAT=IZERO)
   CALL ChkMemErr('OUTGEOM','SURF_IDS',IZERO)

   ALLOCATE(VOLUS(MAX(1,4*N_VOLUS)),STAT=IZERO)
   CALL ChkMemErr('OUTGEOM','VOLUS',IZERO)

   ALLOCATE(MATL_IDS(MAX(1,N_VOLUS)),STAT=IZERO)
   CALL ChkMemErr('OUTGEOM','MATL_IDS',IZERO)

   IF (N_VERTS>0 .AND. (N_FACES>0 .OR. N_VOLUS>0)) THEN
      CALL MERGE_GEOMS(VERTS,N_VERTS,FACES,TFACES,SURF_IDS,N_FACES,VOLUS,MATL_IDS,N_VOLUS,IS_DYNAMIC)
   ENDIF

   WRITE(LUNIT) REAL(TIME,FB)
   WRITE(LUNIT) N_VERTS, N_FACES, N_VOLUS
   IF (N_VERTS>0) WRITE(LUNIT) (REAL(VERTS(I),FB), I=1,3*N_VERTS)
   IF (N_FACES>0) THEN
      WRITE(LUNIT) (FACES(I), I=1,3*N_FACES)
      WRITE(LUNIT) (SURF_IDS(I), I=1,N_FACES)
      WRITE(LUNIT) (REAL(TFACES(I),FB), I=1,6*N_FACES)
   ENDIF
   IF (N_VOLUS>0) THEN
      WRITE(LUNIT) (VOLUS(I), I=1,4*N_VOLUS)
      WRITE(LUNIT) (MATL_IDS(I), I=1,N_VOLUS)
   ENDIF
   
END SUBROUTINE OUTGEOM

! ---------------------------- WRITE_GEOM_ALL ------------------------------------

SUBROUTINE WRITE_GEOM_ALL
INTEGER :: I
REAL(EB) :: STIME

CALL WRITE_GEOM(T_BEGIN) ! write out both static and dynamic data at t=T_BEGIN
DO I = 1, NFRAMES
   STIME = (T_BEGIN*REAL(NFRAMES-I,EB) + T_END_GEOM*REAL(I,EB))/REAL(NFRAMES,EB)
   CALL WRITE_GEOM(STIME) ! write out just dynamic data at t=STIME
ENDDO
END SUBROUTINE WRITE_GEOM_ALL

! ---------------------------- WRITE_GEOM ----------------------------------------

SUBROUTINE WRITE_GEOM(TIME)

! output geometries to a .ge file

   REAL(EB), INTENT(IN) :: TIME
   INTEGER :: ONE=1, ZERO=0, VERSION=2

   IF (N_GEOMETRY<=0) RETURN

   IF (ABS(TIME-T_BEGIN)<TWO_EPSILON_EB) THEN
      OPEN(LU_GEOM(1),FILE=TRIM(FN_GEOM(1)),FORM='UNFORMATTED',STATUS='REPLACE')
      WRITE(LU_GEOM(1)) ONE
      WRITE(LU_GEOM(1)) VERSION
      WRITE(LU_GEOM(1)) ZERO, ZERO, ONE ! n floats, n ints, first frame static
      CALL OUTGEOM(LU_GEOM(1),.FALSE.,TIME) ! write out static data
   ELSE
      OPEN(LU_GEOM(1),FILE=FN_GEOM(1),FORM='UNFORMATTED',STATUS='OLD',POSITION='APPEND')
   ENDIF
   CALL OUTGEOM(LU_GEOM(1),.TRUE.,TIME) ! write out dynamic data
   CLOSE(LU_GEOM(1))
   
END SUBROUTINE WRITE_GEOM

! ---------------------------- READ_VERT ----------------------------------------

SUBROUTINE READ_VERT

REAL(EB) :: X(3)=0._EB
INTEGER :: I,IOS,IZERO
NAMELIST /VERT/ X

N_VERT=0
REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
COUNT_VERT_LOOP: DO
   CALL CHECKREAD('VERT',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_VERT_LOOP
   READ(LU_INPUT,NML=VERT,END=14,ERR=15,IOSTAT=IOS)
   N_VERT=N_VERT+1
   15 IF (IOS>0) CALL SHUTDOWN('ERROR: problem with VERT line')
ENDDO COUNT_VERT_LOOP
14 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

IF (N_VERT==0) RETURN

! Allocate VERTEX array

ALLOCATE(VERTEX(N_VERT),STAT=IZERO)
CALL ChkMemErr('READ_VERT','VERTEX',IZERO)

READ_VERT_LOOP: DO I=1,N_VERT
   
   CALL CHECKREAD('VERT',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_VERT_LOOP
   
   ! Read the VERT line
   
   READ(LU_INPUT,VERT,END=36)
   
   VERTEX(I)%X = X(1)
   VERTEX(I)%Y = X(2)
   VERTEX(I)%Z = X(3)

ENDDO READ_VERT_LOOP
36 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

END SUBROUTINE READ_VERT

! ---------------------------- READ_FACE ----------------------------------------

SUBROUTINE READ_FACE

INTEGER :: N(3),I,IOS,IZERO,NNN,NS
LOGICAL :: EX
CHARACTER(LABEL_LENGTH) :: SURF_ID='INERT'
CHARACTER(MESSAGE_LENGTH) :: MESSAGE
NAMELIST /FACE/ N,SURF_ID

N_FACE=0
REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
COUNT_FACE_LOOP: DO
   CALL CHECKREAD('FACE',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_FACE_LOOP
   READ(LU_INPUT,NML=FACE,END=16,ERR=17,IOSTAT=IOS)
   N_FACE=N_FACE+1
   16 IF (IOS>0) CALL SHUTDOWN('ERROR: problem with FACE line')
ENDDO COUNT_FACE_LOOP
17 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

IF (N_FACE==0) RETURN

! Allocate FACET array

ALLOCATE(FACET(N_FACE),STAT=IZERO)
CALL ChkMemErr('READ_FACE','FACET',IZERO)

READ_FACE_LOOP: DO I=1,N_FACE
   
   CALL CHECKREAD('FACE',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_FACE_LOOP
   
   ! Read the FACE line
   
   READ(LU_INPUT,FACE,END=37)

   IF (ANY(N>N_VERT)) THEN
      WRITE(MESSAGE,'(A,A,A)') 'ERROR: problem with FACE line ',TRIM(CHAR(I)),', N>N_VERT' 
      CALL SHUTDOWN(MESSAGE)
   ENDIF
   
   FACET(I)%VERTEX(1) = N(1)
   FACET(I)%VERTEX(2) = N(2)
   FACET(I)%VERTEX(3) = N(3)

   ! Check the SURF_ID against the list of SURF's

   EX = .FALSE.
   DO NS=0,N_SURF
      IF (TRIM(SURF_ID)==SURFACE(NS)%ID) EX = .TRUE.
   ENDDO
   IF (.NOT.EX) THEN
      WRITE(MESSAGE,'(A,A,A)') 'ERROR: SURF_ID ',TRIM(SURF_ID),' not found'
      CALL SHUTDOWN(MESSAGE)
   ENDIF

   ! Assign SURF_INDEX, Index of the Boundary Condition

   FACET(I)%SURF_ID = TRIM(SURF_ID)
   FACET(I)%SURF_INDEX = DEFAULT_SURF_INDEX
   DO NNN=0,N_SURF
      IF (SURF_ID==SURFACE(NNN)%ID) FACET(I)%SURF_INDEX = NNN
   ENDDO

   ! Allocate 1D arrays

   ALLOCATE(FACET(I)%RHODW(N_TRACKED_SPECIES),STAT=IZERO)
   CALL ChkMemErr('READ_FACE','FACET%RHODW',IZERO)
   ALLOCATE(FACET(I)%ZZ_F(N_TRACKED_SPECIES),STAT=IZERO)
   CALL ChkMemErr('READ_FACE','FACET%ZZ_F',IZERO)

ENDDO READ_FACE_LOOP
37 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

CALL INIT_FACE

END SUBROUTINE READ_FACE

! ---------------------------- INIT_FACE ----------------------------------------

SUBROUTINE INIT_FACE
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT
IMPLICIT NONE

INTEGER :: I,IZERO
REAL(EB) :: N_VEC(3),N_LENGTH,U_VEC(3),V_VEC(3),V1(3),V2(3),V3(3)
TYPE(FACET_TYPE), POINTER :: FC
TYPE(SURFACE_TYPE), POINTER :: SF
REAL(EB), PARAMETER :: TOL=1.E-10_EB

DO I=1,N_FACE

   FC=>FACET(I)

   V1 = (/VERTEX(FC%VERTEX(1))%X,VERTEX(FC%VERTEX(1))%Y,VERTEX(FC%VERTEX(1))%Z/)
   V2 = (/VERTEX(FC%VERTEX(2))%X,VERTEX(FC%VERTEX(2))%Y,VERTEX(FC%VERTEX(2))%Z/)
   V3 = (/VERTEX(FC%VERTEX(3))%X,VERTEX(FC%VERTEX(3))%Y,VERTEX(FC%VERTEX(3))%Z/)

   U_VEC = V2-V1
   V_VEC = V3-V1

   CALL CROSS_PRODUCT(N_VEC,U_VEC,V_VEC)
   N_LENGTH = SQRT(DOT_PRODUCT(N_VEC,N_VEC))

   IF (N_LENGTH>TOL) THEN
      FC%NVEC = N_VEC/N_LENGTH
   ELSE
      FC%NVEC = 0._EB
   ENDIF

   FC%AW = TRIANGLE_AREA(V1,V2,V3)
   IF (SURFACE(FC%SURF_INDEX)%TMP_FRONT>0._EB) THEN
      FC%TMP_F = SURFACE(FC%SURF_INDEX)%TMP_FRONT
   ELSE
      FC%TMP_F = TMPA
   ENDIF
   FC%TMP_G = TMPA
   FC%BOUNDARY_TYPE = SOLID_BOUNDARY

   IF (RADIATION) THEN
      SF => SURFACE(FC%SURF_INDEX)
      IF (ALLOCATED(FC%ILW)) DEALLOCATE(FC%ILW)
      ALLOCATE(FC%ILW(1:SF%NRA,1:SF%NSB),STAT=IZERO)
      CALL ChkMemErr('INIT_FACE','FC%ILW',IZERO)
   ENDIF

ENDDO

! Surface work arrays

IF (RADIATION) THEN
   IF (ALLOCATED(FACE_WORK1)) DEALLOCATE(FACE_WORK1)
   ALLOCATE(FACE_WORK1(N_FACE),STAT=IZERO)
   CALL ChkMemErr('INIT_FACE','FACE_WORK1',IZERO)
   IF (ALLOCATED(FACE_WORK2)) DEALLOCATE(FACE_WORK2)
   ALLOCATE(FACE_WORK2(N_FACE),STAT=IZERO)
   CALL ChkMemErr('INIT_FACE','FACE_WORK2',IZERO)
ENDIF

END SUBROUTINE INIT_FACE

! ---------------------------- READ_VOLU ----------------------------------------

SUBROUTINE READ_VOLU

INTEGER :: N(4),I,IOS,IZERO
CHARACTER(LABEL_LENGTH) :: MATL_ID
NAMELIST /VOLU/ N,MATL_ID

N_VOLU=0
REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0
COUNT_VOLU_LOOP: DO
   CALL CHECKREAD('VOLU',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_VOLU_LOOP
   READ(LU_INPUT,NML=VOLU,END=18,ERR=19,IOSTAT=IOS)
   N_VOLU=N_VOLU+1
   18 IF (IOS>0) CALL SHUTDOWN('ERROR: problem with VOLU line')
ENDDO COUNT_VOLU_LOOP
19 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

IF (N_VOLU==0) RETURN

! Allocate VOLUME array

ALLOCATE(VOLUME(N_VOLU),STAT=IZERO)
CALL ChkMemErr('READ_VOLU','VOLU',IZERO)

READ_VOLU_LOOP: DO I=1,N_VOLU
   
   CALL CHECKREAD('VOLU',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_VOLU_LOOP
   
   ! Read the VOLU line
   
   READ(LU_INPUT,VOLU,END=38)
   
   VOLUME(I)%VERTEX(1) = N(1)
   VOLUME(I)%VERTEX(2) = N(2)
   VOLUME(I)%VERTEX(3) = N(3)
   VOLUME(I)%VERTEX(4) = N(4)
   VOLUME(I)%MATL_ID = TRIM(MATL_ID)

ENDDO READ_VOLU_LOOP
38 REWIND(LU_INPUT) ; INPUT_FILE_LINE_NUMBER = 0

END SUBROUTINE READ_VOLU

! ---------------------------- INIT_IBM ----------------------------------------

SUBROUTINE INIT_IBM(T,NM)
USE COMP_FUNCTIONS, ONLY: GET_FILE_NUMBER
USE PHYSICAL_FUNCTIONS, ONLY: LES_FILTER_WIDTH_FUNCTION
USE BOXTETRA_ROUTINES, ONLY: TETRAHEDRON_VOLUME
IMPLICIT NONE
INTEGER, INTENT(IN) :: NM
REAL(EB), INTENT(IN) :: T
INTEGER :: I,J,K,N,IERR,IERR1,IERR2,I_MIN,I_MAX,J_MIN,J_MAX,K_MIN,K_MAX,IC,IOR,IIG,JJG,KKG
INTEGER :: NP,NXP,IZERO,LU,CUTCELL_COUNT,OWNER_INDEX,VERSION,NV,NF,NVO,DUMMY_INTEGER
TYPE (MESH_TYPE), POINTER :: M
REAL(EB) :: BB(6),V1(3),V2(3),V3(3),V4(3),AREA,PC(18),XPC(60),V_POLYGON_CENTROID(3),VC,AREA_CHECK
LOGICAL :: EX,OP
CHARACTER(60) :: FN
CHARACTER(MESSAGE_LENGTH) :: MESSAGE
REAL(FB) :: TIME_STRU
REAL(EB), PARAMETER :: CUTCELL_TOLERANCE=1.E+10_EB,MIN_AREA=1.E-16_EB,TOL=1.E-9_EB
!LOGICAL :: END_OF_LIST
TYPE(FACET_TYPE), POINTER :: FC=>NULL()
TYPE(CUTCELL_LINKED_LIST_TYPE), POINTER :: CL=>NULL()
TYPE(CUTCELL_TYPE), POINTER :: CC=>NULL()
TYPE(GEOMETRY_TYPE), POINTER :: G

IF (EVACUATION_ONLY(NM)) RETURN
M => MESHES(NM)

! reinitialize complex geometry from geometry coordinate (.gc) file based on DT_GEOC frequency

IF (T<GEOC_CLOCK) RETURN
GEOC_CLOCK = GEOC_CLOCK + DT_GEOC
IF (ABS(T-T_BEGIN)<TWO_EPSILON_EB) THEN
   IZERO = 0
   IF (.NOT.ALLOCATED(M%CUTCELL_INDEX)) THEN
      ALLOCATE(M%CUTCELL_INDEX(0:IBP1,0:JBP1,0:KBP1),STAT=IZERO) 
      CALL ChkMemErr('INIT_IBM','M%CUTCELL_INDEX',IZERO) 
   ENDIF
ENDIF

M%CUTCELL_INDEX = 0
CUTCELL_COUNT = 0

GEOC_LOOP: DO N=1,N_GEOMETRY
G => GEOMETRY(N)
   IF (TRIM(G%GEOC_FILENAME)=='null' .OR. T==0.0) CYCLE

   FN = TRIM(G%GEOC_FILENAME)
   INQUIRE(FILE=FN,EXIST=EX,OPENED=OP,NUMBER=LU)
   IF (.NOT.EX) CALL SHUTDOWN('ERROR: GEOMetry Coordinate file does not exist.')
   IF (OP) CLOSE(LU)
   LU_GEOC = GET_FILE_NUMBER()

   GEOC_CHECK_LOOP: DO I=1,30
      OPEN(LU_GEOC,FILE=FN,ACTION='READ',FORM='UNFORMATTED')
      READ(LU_GEOC) OWNER_INDEX     ! 1 - written by FEM, 0 - already read by FDS
      IF (OWNER_INDEX==1) EXIT GEOC_CHECK_LOOP

       CLOSE(LU_GEOC)
       IF (I==1) THEN
          WRITE (LU_ERR,'(4X,A)')  'waiting ANSYS new geometry ... '
          LU_GEOC = GET_FILE_NUMBER()
          OPEN(LU_GEOC,FILE=FN,ACTION='WRITE',FORM='UNFORMATTED')
          OWNER_INDEX=2           ! 2 - .be already written
          WRITE(LU_GEOC) OWNER_INDEX
          CLOSE(LU_GEOC)  
       ELSE 
          WRITE(LU_ERR,'(4X,A,I2,A)')  'waiting ... ', I-1,' min'
       ENDIF
       CALL SLEEP(60)
       IF (I==30) CALL SHUTDOWN('ERROR: BNDC FILE WAS NOT UPDATED BY STRUCTURE CODE')
   ENDDO GEOC_CHECK_LOOP  

   IF (OWNER_INDEX==1) THEN
      READ(LU_GEOC) VERSION
      READ(LU_GEOC) TIME_STRU ! stime
      READ(LU_GEOC) NV, NF, NVO

      IF (NV>0 .AND. .NOT.ALLOCATED(FB_REAL_VERT_ARRAY)) THEN
         ALLOCATE(FB_REAL_VERT_ARRAY(NV*3),STAT=IZERO)
         CALL ChkMemErr('INIT_IBM','FB_REAL_VERT_ARRAY',IZERO)
      ENDIF
      IF (NF>0) THEN
         IF (.NOT.ALLOCATED(INT_FACE_VALS_ARRAY)) THEN
            ALLOCATE(INT_FACE_VALS_ARRAY(NF*3),STAT=IZERO)
            CALL ChkMemErr('INIT_IBM','INT_FACE_VALS_ARRAY',IZERO)
         ENDIF
         IF (.NOT.ALLOCATED(INT_SURF_VALS_ARRAY)) THEN
            ALLOCATE(INT_SURF_VALS_ARRAY(NF),STAT=IZERO)
            CALL ChkMemErr('INIT_IBM','INT_SURF_VALS_ARRAY',IZERO)
         ENDIF
      ENDIF
      IF (NVO>0) THEN             
         IF (.NOT.ALLOCATED(INT_VOLS_VALS_ARRAY)) THEN
            ALLOCATE(INT_VOLS_VALS_ARRAY(NVO*4),STAT=IZERO)
            CALL ChkMemErr('INIT_IBM','INT_VOLS_VALS_ARRAY',IZERO)
         ENDIF
         IF (.NOT.ALLOCATED(INT_MATL_VALS_ARRAY)) THEN
            ALLOCATE(INT_MATL_VALS_ARRAY(NVO),STAT=IZERO)
            CALL ChkMemErr('INIT_IBM','INT_MATL_VALS_ARRAY',IZERO)
         ENDIF         
      ENDIF

      IF (NV>0) THEN
         READ(LU_GEOC) ((FB_REAL_VERT_ARRAY((I-1)*3+J),J=1,3),I=1,NV)
         G%VERTS = REAL(FB_REAL_VERT_ARRAY,EB)
      ENDIF

      DO I=1,NV
         VERTEX(I)%X = REAL(FB_REAL_VERT_ARRAY((I-1)*3+1),EB)
         VERTEX(I)%Y = REAL(FB_REAL_VERT_ARRAY((I-1)*3+2),EB)
         VERTEX(I)%Z = REAL(FB_REAL_VERT_ARRAY((I-1)*3+3),EB)
      ENDDO
      IF (NF>0) READ(LU_GEOC) ((INT_FACE_VALS_ARRAY((I-1)*3+J),J=1,3),I=1,NF)
      IF (NF>0) READ(LU_GEOC) (INT_SURF_VALS_ARRAY(I),I=1,NF)
      IF (NVO>0) READ(LU_GEOC) ((INT_VOLS_VALS_ARRAY((I-1)*4+J),J=1,4),I=1,NVO)
      IF (NVO>0) READ(LU_GEOC) (INT_MATL_VALS_ARRAY(I),I=1,NVO)                

      WRITE(LU_ERR,'(4X,A,F10.2,A,F10.2)')  'GEOM was updated at ',T,' s, GEOM Time:', TIME_STRU
      CLOSE(LU_GEOC)
      
      OPEN(LU_GEOC,FILE=FN,FORM='UNFORMATTED',STATUS='OLD')
      OWNER_INDEX=0.0
      WRITE(LU_GEOC) OWNER_INDEX     ! 1 - written by FEM, 0 - already read by FDS
      CLOSE(LU_GEOC)
      CALL WRITE_GEOM(T)
   ENDIF 

ENDDO GEOC_LOOP

! define geometry data structures whenever geometry changes

IF (GEOMETRY_CHANGE_STATE==1) CALL CONVERTGEOM(T)

FACE_LOOP: DO N=1,N_FACE

   ! re-initialize the cutcell linked list
   IF (ASSOCIATED(FACET(N)%CUTCELL_LIST)) CALL CUTCELL_DESTROY(FACET(N)%CUTCELL_LIST)

   V1 = (/VERTEX(FACET(N)%VERTEX(1))%X,VERTEX(FACET(N)%VERTEX(1))%Y,VERTEX(FACET(N)%VERTEX(1))%Z/)
   V2 = (/VERTEX(FACET(N)%VERTEX(2))%X,VERTEX(FACET(N)%VERTEX(2))%Y,VERTEX(FACET(N)%VERTEX(2))%Z/)
   V3 = (/VERTEX(FACET(N)%VERTEX(3))%X,VERTEX(FACET(N)%VERTEX(3))%Y,VERTEX(FACET(N)%VERTEX(3))%Z/)
   FACET(N)%AW = TRIANGLE_AREA(V1,V2,V3)
   
   BB(1) = MIN(V1(1),V2(1),V3(1))
   BB(2) = MAX(V1(1),V2(1),V3(1))
   BB(3) = MIN(V1(2),V2(2),V3(2))
   BB(4) = MAX(V1(2),V2(2),V3(2))
   BB(5) = MIN(V1(3),V2(3),V3(3))
   BB(6) = MAX(V1(3),V2(3),V3(3))
   
   I_MIN = MAX(1,FLOOR((BB(1)-M%XS)/M%DX(1))-1) ! assumes uniform grid for now
   J_MIN = MAX(1,FLOOR((BB(3)-M%YS)/M%DY(1))-1)
   K_MIN = MAX(1,FLOOR((BB(5)-M%ZS)/M%DZ(1))-1)

   I_MAX = MIN(M%IBAR,CEILING((BB(2)-M%XS)/M%DX(1))+1)
   J_MAX = MIN(M%JBAR,CEILING((BB(4)-M%YS)/M%DY(1))+1)
   K_MAX = MIN(M%KBAR,CEILING((BB(6)-M%ZS)/M%DZ(1))+1)

   DO K=K_MIN,K_MAX
      DO J=J_MIN,J_MAX
         DO I=I_MIN,I_MAX

            BB(1) = M%X(I-1)
            BB(2) = M%X(I)
            BB(3) = M%Y(J-1)
            BB(4) = M%Y(J)
            BB(5) = M%Z(K-1)
            BB(6) = M%Z(K)
            CALL TRIANGLE_BOX_INTERSECT(IERR,V1,V2,V3,BB)
            
            IF (IERR==1) THEN
               CALL TRIANGLE_ON_CELL_SURF(IERR1,FACET(N)%NVEC,V1,M%XC(I),M%YC(J),M%ZC(K),M%DX(I),M%DY(J),M%DZ(K))  
               IF (IERR1==-1) CYCLE ! remove the possibility of double counting
                              
               CALL TRI_PLANE_BOX_INTERSECT(NP,PC,V1,V2,V3,BB)
               CALL TRIANGLE_POLYGON_POINTS(IERR2,NXP,XPC,V1,V2,V3,NP,PC,BB)
               IF (IERR2==1)  THEN                  
                  AREA = POLYGON_AREA(NXP,XPC)
                  IF (AREA > MIN_AREA) THEN
                     
                     ! check if the cutcell area needs to be assigned to a neighbor cell
                     V_POLYGON_CENTROID = POLYGON_CENTROID(NXP,XPC)
                     CALL POLYGON_CLOSE_TO_EDGE(IOR,FACET(N)%NVEC,V_POLYGON_CENTROID,&
                                                M%XC(I),M%YC(J),M%ZC(K),M%DX(I),M%DY(J),M%DZ(K))
                     IF (IOR/=0) THEN ! assign the cutcell area to a neighbor cell
                        SELECT CASE(IOR)
                           CASE(1)
                              IF (I==M%IBAR) THEN 
                                 IOR=0
                                 EXIT
                              ENDIF
                              IF (M%CUTCELL_INDEX(I+1,J,K)==0) THEN
                                 CUTCELL_COUNT = CUTCELL_COUNT+1
                                 IC = CUTCELL_COUNT
                                 M%CUTCELL_INDEX(I+1,J,K) = IC
                               ELSE
                                 IC = M%CUTCELL_INDEX(I+1,J,K)
                               ENDIF
                           CASE(-1)
                              IF (I==1) THEN 
                                 IOR=0
                                 EXIT
                              ENDIF
                              IF (M%CUTCELL_INDEX(I-1,J,K)==0) THEN
                                 CUTCELL_COUNT = CUTCELL_COUNT+1
                                 IC = CUTCELL_COUNT
                                 M%CUTCELL_INDEX(I-1,J,K) = IC
                               ELSE
                                 IC = M%CUTCELL_INDEX(I-1,J,K)
                               ENDIF
                           CASE(2)
                              IF (J==M%JBAR) THEN 
                                 IOR=0
                                 EXIT
                              ENDIF
                              IF (M%CUTCELL_INDEX(I,J+1,K)==0) THEN
                                 CUTCELL_COUNT = CUTCELL_COUNT+1
                                 IC = CUTCELL_COUNT
                                 M%CUTCELL_INDEX(I,J+1,K) = IC
                               ELSE
                                 IC = M%CUTCELL_INDEX(I,J+1,K)
                               ENDIF
                           CASE(-2)
                              IF (J==1) THEN 
                                 IOR=0
                                 EXIT
                              ENDIF
                              IF (M%CUTCELL_INDEX(I,J-1,K)==0) THEN
                                 CUTCELL_COUNT = CUTCELL_COUNT+1
                                 IC = CUTCELL_COUNT
                                 M%CUTCELL_INDEX(I,J-1,K) = IC
                               ELSE
                                 IC = M%CUTCELL_INDEX(I,J-1,K)
                               ENDIF
                           CASE(3)
                              IF (K==M%KBAR) THEN 
                                 IOR=0
                                 EXIT
                              ENDIF
                              IF (M%CUTCELL_INDEX(I,J,K+1)==0) THEN
                                 CUTCELL_COUNT = CUTCELL_COUNT+1
                                 IC = CUTCELL_COUNT
                                 M%CUTCELL_INDEX(I,J,K+1) = IC
                               ELSE
                                 IC = M%CUTCELL_INDEX(I,J,K+1)
                               ENDIF
                           CASE(-3)
                              IF (K==1) THEN 
                                 IOR=0
                                 EXIT
                              ENDIF
                              IF (M%CUTCELL_INDEX(I,J,K-1)==0) THEN
                                 CUTCELL_COUNT = CUTCELL_COUNT+1
                                 IC = CUTCELL_COUNT
                                 M%CUTCELL_INDEX(I,J,K-1) = IC
                               ELSE
                                 IC = M%CUTCELL_INDEX(I,J,K-1)
                               ENDIF
                        END SELECT
                     ENDIF
                     
                     IF (IOR==0) THEN 
                        IF (M%CUTCELL_INDEX(I,J,K)==0) THEN
                           CUTCELL_COUNT = CUTCELL_COUNT+1
                           IC = CUTCELL_COUNT
                           M%CUTCELL_INDEX(I,J,K) = IC
                        ELSE
                           IC = M%CUTCELL_INDEX(I,J,K)
                        ENDIF
                     ENDIF
                                            
                     CALL CUTCELL_INSERT(IC,AREA,FACET(N)%CUTCELL_LIST)
                  ENDIF
               ENDIF
            ENDIF

         ENDDO
      ENDDO
   ENDDO

ENDDO FACE_LOOP

! Create arrays to hold cutcell indices

CUTCELL_INDEX_IF: IF (CUTCELL_COUNT>0) THEN

   IF (ALLOCATED(M%I_CUTCELL)) DEALLOCATE(M%I_CUTCELL)
   IF (ALLOCATED(M%J_CUTCELL)) DEALLOCATE(M%J_CUTCELL)
   IF (ALLOCATED(M%K_CUTCELL)) DEALLOCATE(M%K_CUTCELL)
   IF (ALLOCATED(M%CUTCELL))   DEALLOCATE(M%CUTCELL)

   ALLOCATE(M%I_CUTCELL(CUTCELL_COUNT),STAT=IZERO) 
   CALL ChkMemErr('INIT_IBM','M%I_CUTCELL',IZERO) 
   M%I_CUTCELL = -1
   
   ALLOCATE(M%J_CUTCELL(CUTCELL_COUNT),STAT=IZERO) 
   CALL ChkMemErr('INIT_IBM','M%J_CUTCELL',IZERO) 
   M%J_CUTCELL = -1
   
   ALLOCATE(M%K_CUTCELL(CUTCELL_COUNT),STAT=IZERO) 
   CALL ChkMemErr('INIT_IBM','M%K_CUTCELL',IZERO) 
   M%K_CUTCELL = -1

   ALLOCATE(M%CUTCELL(CUTCELL_COUNT),STAT=IZERO) 
   CALL ChkMemErr('INIT_IBM','M%CUTCELL',IZERO) 
 
   DO K=0,KBP1
      DO J=0,JBP1
         DO I=0,IBP1
            IC = M%CUTCELL_INDEX(I,J,K)
            IF (IC>0) THEN
               M%I_CUTCELL(IC) = I
               M%J_CUTCELL(IC) = J
               M%K_CUTCELL(IC) = K
               M%P_MASK(I,J,K) = 0

               ! new stuff -- specific to tet_fire_1.fds
               CC=>M%CUTCELL(IC)
               VC = M%DX(I)*M%DY(J)*M%DZ(K)
               CC%A(1) = M%DY(J)*M%DZ(K)
               CC%A(2) = M%DY(J)*M%DZ(K)
               CC%A(3) = M%DX(I)*M%DZ(K)
               CC%A(4) = M%DX(I)*M%DZ(K)
               CC%A(5) = M%DX(I)*M%DY(J)
               CC%A(6) = M%DX(I)*M%DY(J)

               IF (I==4 .OR. J==13 .OR. K==13) THEN
                  CC%VOL = VC
                  IF (I==4) THEN
                     CC%S = CC%A(2)
                     CC%N = (/-1._EB,0._EB,0._EB/)
                  ENDIF
                  IF (J==13) THEN
                     CC%S = CC%A(3)
                     CC%N = (/0._EB,1._EB,0._EB/)
                  ENDIF
                  IF (K==13) THEN
                     CC%S = CC%A(5)
                     CC%N = (/0._EB,0._EB,1._EB/)
                  ENDIF
               ELSE
                  V1 = (/X(I-1),Y(J),Z(K-1)/)
                  V2 = (/X(I-1),Y(J),Z(K)/)
                  V3 = (/X(I-1),Y(J-1),Z(K)/)
                  V4 = (/X(I),Y(J),Z(K)/)
                  CC%VOL = VC - TETRAHEDRON_VOLUME(V1,V2,V3,V4)
                  CC%A(1) = 0.5_EB*CC%A(1)
                  CC%A(4) = 0.5_EB*CC%A(4)
                  CC%A(6) = 0.5_EB*CC%A(6)
                  ! area = 1/2 * base * height
                  CC%S = 0.5_EB * SQRT(M%DX(I)**2 + M%DY(J)**2) * SQRT(0.5_EB*MAX((M%DX(I)**2-M%DY(J)**2),0._EB) + M%DZ(K)**2)
                  CC%N = (/M%DX(I),M%DY(J),-M%DZ(K)/)
                  CC%N = CC%N/SQRT(DOT_PRODUCT(CC%N,CC%N)) ! normalize
               ENDIF

               CC%RHO = RHOA
               CC%TMP = TMPA
               ALLOCATE(CC%ZZ(N_TRACKED_SPECIES),STAT=IZERO)
               CALL ChkMemErr('INIT_IBM','M%CUTCELL%ZZ',IZERO)

               !print *, CC%VOL, VC

            ENDIF
         ENDDO
      ENDDO
   ENDDO

ENDIF CUTCELL_INDEX_IF

!CL=>FACET(1)%CUTCELL_LIST
!IF ( ASSOCIATED(CL) ) THEN
!    END_OF_LIST=.FALSE.
!    DO WHILE (.NOT.END_OF_LIST)
!       print *, CL%INDEX, CL%AREA
!       CL=>CL%NEXT
!       IF ( .NOT.ASSOCIATED(CL) ) THEN
!          print *,'done printing linked list!'
!          END_OF_LIST=.TRUE.
!       ENDIF
!    ENDDO
!ENDIF

! Set up any face parameters related to cutcells and check area sums

DO N=1,N_FACE

   FC=>FACET(N)
   CL=>FC%CUTCELL_LIST

   FC%DN=0._EB
   FC%RDN=0._EB
   AREA_CHECK=0._EB

   CUTCELL_LOOP: DO
      IF ( .NOT. ASSOCIATED(CL) ) EXIT CUTCELL_LOOP ! if the next index does not exist, exit the loop
      IC = CL%INDEX
      IIG = M%I_CUTCELL(IC)
      JJG = M%J_CUTCELL(IC)
      KKG = M%K_CUTCELL(IC)
      VC = M%DX(IIG)*M%DY(JJG)*M%DZ(KKG)

      FC%DN = FC%DN + CL%AREA*VC

      AREA_CHECK = AREA_CHECK + CL%AREA

      CL=>CL%NEXT ! point to the next index in the linked list
   ENDDO CUTCELL_LOOP

   IF (ABS(FC%AW-AREA_CHECK)>CUTCELL_TOLERANCE) THEN
      WRITE(MESSAGE,'(A,1I4)') 'ERROR: cutcell area checksum failed for facet ',N
      CALL SHUTDOWN(MESSAGE)
   ENDIF

   IF (FC%DN>CUTCELL_TOLERANCE) THEN
      FC%DN = FC%DN**ONTH ! wall normal length scale
      FC%RDN = 1._EB/FC%DN
   ENDIF

ENDDO

! Read boundary condition from file

BNDC_LOOP: DO N=1,N_GEOMETRY
   IF (TRIM(GEOMETRY(N)%BNDC_FILENAME)=='null') CYCLE
   
   FN = TRIM(GEOMETRY(N)%BNDC_FILENAME)
   INQUIRE(FILE=FN,EXIST=EX,OPENED=OP,NUMBER=LU)
   IF (.NOT.EX) CALL SHUTDOWN('Error: boundary condition file does not exist.')
   IF (OP) CLOSE(LU)
   LU_BNDC = GET_FILE_NUMBER()
      
   BNDC_CHECK_LOOP: DO I=1,30
      OPEN(LU_BNDC,FILE=FN,ACTION='READ',FORM='UNFORMATTED')
      READ(LU_BNDC) OWNER_INDEX     ! 1 means written by FEM, 0 by FDS
      READ(LU_BNDC) VERSION         ! version
      READ(LU_BNDC) TIME_STRU       ! stime
      IF (OWNER_INDEX /=1 .OR. T-REAL(TIME_STRU,EB)>DT_BNDC*0.1_EB) THEN
         CLOSE(LU_BNDC)
         WRITE(LU_ERR,'(4X,A,F10.2,A)')  'BNDC not updated at ',T,' s'
         ! this call was breaking an FDS build - ***gf
         ! CALL sleep(1)
      ELSE
         WRITE(LU_ERR,'(4X,A,F10.2,A)')  'BNDC was updated at ',T,' s'
         EXIT BNDC_CHECK_LOOP
      ENDIF
      IF (I==30) THEN
         IF (OWNER_INDEX==0) THEN
            CALL SHUTDOWN("ERROR: BNDC FILE WAS NOT UPDATED BY STRUCTURE CODE")
         ELSE
            CALL SHUTDOWN("ERROR: TIME MARKS do not match")
         ENDIF
      ENDIF
   ENDDO BNDC_CHECK_LOOP
   
   IF (ALLOCATED(FB_REAL_FACE_VALS_ARRAY)) DEALLOCATE(FB_REAL_FACE_VALS_ARRAY)
   ALLOCATE(FB_REAL_FACE_VALS_ARRAY(N_FACE),STAT=IZERO)
   CALL ChkMemErr('INIT_IBM','FB_REAL_FACE_VALS_ARRAY',IZERO)

   IF (T>=REAL(TIME_STRU,EB)) THEN
      ! n_vert_s_vals,n_vert_d_vals,n_face_s_vals,n_face_d_vals
      READ(LU_BNDC) (DUMMY_INTEGER,I=1,4)
      READ(LU_BNDC) (FB_REAL_FACE_VALS_ARRAY(I),I=1,N_FACE)
      DO I=1,N_FACE
         FC=>FACET(I)
         FC%TMP_F = REAL(FB_REAL_FACE_VALS_ARRAY(I),EB) + TMPM
      ENDDO
      IBM_FEM_COUPLING=.TRUE. ! immersed boundary method / finite-element method coupling
   ELSE
      BACKSPACE LU_BNDC
   ENDIF

ENDDO BNDC_LOOP

END SUBROUTINE INIT_IBM

! ---------------------------- LINKED_LIST_INSERT ----------------------------------------

! http://www.sdsc.edu/~tkaiser/f90.html#Linked lists
RECURSIVE SUBROUTINE LINKED_LIST_INSERT(ITEM,ROOT) 
   IMPLICIT NONE 
   TYPE(LINKED_LIST_TYPE), POINTER :: ROOT 
   INTEGER :: ITEM,IZERO
   IF (.NOT.ASSOCIATED(ROOT)) THEN 
      ALLOCATE(ROOT,STAT=IZERO)
      CALL ChkMemErr('LINKED_LIST_INSERT','ROOT',IZERO)
      NULLIFY(ROOT%NEXT) 
      ROOT%INDEX = ITEM 
   ELSE 
      CALL LINKED_LIST_INSERT(ITEM,ROOT%NEXT) 
   ENDIF 
END SUBROUTINE LINKED_LIST_INSERT

! ---------------------------- CUTCELL_INSERT ----------------------------------------

RECURSIVE SUBROUTINE CUTCELL_INSERT(ITEM,AREA,ROOT) 
   IMPLICIT NONE 
   TYPE(CUTCELL_LINKED_LIST_TYPE), POINTER :: ROOT 
   INTEGER :: ITEM,IZERO
   REAL(EB):: AREA
   IF (.NOT.ASSOCIATED(ROOT)) THEN 
      ALLOCATE(ROOT,STAT=IZERO)
      CALL ChkMemErr('CUTCELL_INSERT','ROOT',IZERO)
      NULLIFY(ROOT%NEXT) 
      ROOT%INDEX = ITEM
      ROOT%AREA = AREA 
   ELSE 
      CALL CUTCELL_INSERT(ITEM,AREA,ROOT%NEXT) 
   ENDIF 
END SUBROUTINE CUTCELL_INSERT

! ---------------------------- CUTCELL_DESTROY ----------------------------------------

SUBROUTINE CUTCELL_DESTROY(ROOT)
IMPLICIT NONE
TYPE(CUTCELL_LINKED_LIST_TYPE), POINTER :: ROOT,CURRENT
DO WHILE (ASSOCIATED(ROOT))
  CURRENT => ROOT
  ROOT => CURRENT%NEXT
  DEALLOCATE(CURRENT)
ENDDO
RETURN
END SUBROUTINE CUTCELL_DESTROY

! ---------------------------- TRIANGLE_BOX_INTERSECT ----------------------------------------

SUBROUTINE TRIANGLE_BOX_INTERSECT(IERR,V1,V2,V3,BB)
IMPLICIT NONE

INTEGER, INTENT(OUT) :: IERR
REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3),BB(6)
REAL(EB) :: PLANE(4),P0(3),P1(3)

IERR=0

!! Filter small triangles
!
!A_TRI = TRIANGLE_AREA(V1,V2,V3)
!A_BB  = MIN( (BB(2)-BB(1))*(BB(4)-BB(3)), (BB(2)-BB(1))*(BB(6)-BB(5)), (BB(4)-BB(3))*(BB(6)-BB(5)) )
!IF (A_TRI < 0.01*A_BB) RETURN

! Are vertices outside of bounding planes?

IF (MAX(V1(1),V2(1),V3(1))<BB(1)) RETURN
IF (MIN(V1(1),V2(1),V3(1))>BB(2)) RETURN
IF (MAX(V1(2),V2(2),V3(2))<BB(3)) RETURN
IF (MIN(V1(2),V2(2),V3(2))>BB(4)) RETURN
IF (MAX(V1(3),V2(3),V3(3))<BB(5)) RETURN
IF (MIN(V1(3),V2(3),V3(3))>BB(6)) RETURN

! Any vertices inside bounding box?

IF ( V1(1)>=BB(1) .AND. V1(1)<=BB(2) .AND. &
     V1(2)>=BB(3) .AND. V1(2)<=BB(4) .AND. &
     V1(3)>=BB(5) .AND. V1(3)<=BB(6) ) THEN
   IERR=1
   RETURN
ENDIF
IF ( V2(1)>=BB(1) .AND. V2(1)<=BB(2) .AND. &
     V2(2)>=BB(3) .AND. V2(2)<=BB(4) .AND. &
     V2(3)>=BB(5) .AND. V2(3)<=BB(6) ) THEN
   IERR=1
   RETURN
ENDIF
IF ( V3(1)>=BB(1) .AND. V3(1)<=BB(2) .AND. &
     V3(2)>=BB(3) .AND. V3(2)<=BB(4) .AND. &
     V3(3)>=BB(5) .AND. V3(3)<=BB(6) ) THEN
   IERR=1
   RETURN
ENDIF

! There are a couple other trivial rejection tests we could employ.
! But for now we jump straight to line segment--plane intersection.

! Test edge V1,V2 for intersection with each face of box
PLANE = (/-1._EB,0._EB,0._EB, BB(1)/); CALL LINE_PLANE_INTERSECT(IERR,V1,V2,PLANE,BB,-1); IF (IERR==1) RETURN
PLANE = (/ 1._EB,0._EB,0._EB,-BB(2)/); CALL LINE_PLANE_INTERSECT(IERR,V1,V2,PLANE,BB, 1); IF (IERR==1) RETURN
PLANE = (/0._EB,-1._EB,0._EB, BB(3)/); CALL LINE_PLANE_INTERSECT(IERR,V1,V2,PLANE,BB,-2); IF (IERR==1) RETURN
PLANE = (/0._EB, 1._EB,0._EB,-BB(4)/); CALL LINE_PLANE_INTERSECT(IERR,V1,V2,PLANE,BB, 2); IF (IERR==1) RETURN
PLANE = (/0._EB,0._EB,-1._EB, BB(5)/); CALL LINE_PLANE_INTERSECT(IERR,V1,V2,PLANE,BB,-3); IF (IERR==1) RETURN
PLANE = (/0._EB,0._EB, 1._EB,-BB(6)/); CALL LINE_PLANE_INTERSECT(IERR,V1,V2,PLANE,BB, 3); IF (IERR==1) RETURN

! Test edge V2,V3 for intersection with each face of box
PLANE = (/-1._EB,0._EB,0._EB, BB(1)/); CALL LINE_PLANE_INTERSECT(IERR,V2,V3,PLANE,BB,-1); IF (IERR==1) RETURN
PLANE = (/ 1._EB,0._EB,0._EB,-BB(2)/); CALL LINE_PLANE_INTERSECT(IERR,V2,V3,PLANE,BB, 1); IF (IERR==1) RETURN
PLANE = (/0._EB,-1._EB,0._EB, BB(3)/); CALL LINE_PLANE_INTERSECT(IERR,V2,V3,PLANE,BB,-2); IF (IERR==1) RETURN
PLANE = (/0._EB, 1._EB,0._EB,-BB(4)/); CALL LINE_PLANE_INTERSECT(IERR,V2,V3,PLANE,BB, 2); IF (IERR==1) RETURN
PLANE = (/0._EB,0._EB,-1._EB, BB(5)/); CALL LINE_PLANE_INTERSECT(IERR,V2,V3,PLANE,BB,-3); IF (IERR==1) RETURN
PLANE = (/0._EB,0._EB, 1._EB,-BB(6)/); CALL LINE_PLANE_INTERSECT(IERR,V2,V3,PLANE,BB, 3); IF (IERR==1) RETURN

! Test edge V3,V1 for intersection with each face of box
PLANE = (/-1._EB,0._EB,0._EB, BB(1)/); CALL LINE_PLANE_INTERSECT(IERR,V3,V1,PLANE,BB,-1); IF (IERR==1) RETURN
PLANE = (/ 1._EB,0._EB,0._EB,-BB(2)/); CALL LINE_PLANE_INTERSECT(IERR,V3,V1,PLANE,BB, 1); IF (IERR==1) RETURN
PLANE = (/0._EB,-1._EB,0._EB, BB(3)/); CALL LINE_PLANE_INTERSECT(IERR,V3,V1,PLANE,BB,-2); IF (IERR==1) RETURN
PLANE = (/0._EB, 1._EB,0._EB,-BB(4)/); CALL LINE_PLANE_INTERSECT(IERR,V3,V1,PLANE,BB, 2); IF (IERR==1) RETURN
PLANE = (/0._EB,0._EB,-1._EB, BB(5)/); CALL LINE_PLANE_INTERSECT(IERR,V3,V1,PLANE,BB,-3); IF (IERR==1) RETURN
PLANE = (/0._EB,0._EB, 1._EB,-BB(6)/); CALL LINE_PLANE_INTERSECT(IERR,V3,V1,PLANE,BB, 3); IF (IERR==1) RETURN

! The remaining possibility for tri-box intersection is that the corner of the box pokes through
! the triangle such that neither the vertices nor the edges of tri intersect any of the box faces.
! In this case the diagonal of the box corner intersects the plane formed by the tri.  The diagonal
! is defined as the line segment from point P0 to P1, formed from the corners of the bounding box.

! Test the four box diagonals:

P0 = (/BB(1),BB(3),BB(5)/)
P1 = (/BB(2),BB(4),BB(6)/)
CALL LINE_SEGMENT_TRIANGLE_INTERSECT(IERR,V1,V2,V3,P0,P1); IF (IERR==1) RETURN

P0 = (/BB(2),BB(3),BB(5)/)
P1 = (/BB(1),BB(4),BB(6)/)
CALL LINE_SEGMENT_TRIANGLE_INTERSECT(IERR,V1,V2,V3,P0,P1); IF (IERR==1) RETURN

P0 = (/BB(1),BB(3),BB(6)/)
P1 = (/BB(2),BB(4),BB(5)/)
CALL LINE_SEGMENT_TRIANGLE_INTERSECT(IERR,V1,V2,V3,P0,P1); IF (IERR==1) RETURN

P0 = (/BB(1),BB(4),BB(5)/)
P1 = (/BB(2),BB(3),BB(6)/)
CALL LINE_SEGMENT_TRIANGLE_INTERSECT(IERR,V1,V2,V3,P0,P1); IF (IERR==1) RETURN

! test commit from Charles Luo

END SUBROUTINE TRIANGLE_BOX_INTERSECT

! ---------------------------- TRIANGLE_AREA ----------------------------------------

REAL(EB) FUNCTION TRIANGLE_AREA(V1,V2,V3)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT,NORM2
IMPLICIT NONE

REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3)
REAL(EB) :: N(3),R1(3),R2(3)

R1 = V2-V1
R2 = V3-V1
CALL CROSS_PRODUCT(N,R1,R2)

TRIANGLE_AREA = 0.5_EB*NORM2(N)

END FUNCTION TRIANGLE_AREA

! ---------------------------- LINE_SEGMENT_TRIANGLE_INTERSECT ----------------------------------------

SUBROUTINE LINE_SEGMENT_TRIANGLE_INTERSECT(IERR,V1,V2,V3,P0,P1)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT
IMPLICIT NONE

INTEGER, INTENT(OUT) :: IERR
REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3),P0(3),P1(3)
REAL(EB) :: E1(3),E2(3),S(3),Q(3),U,V,TMP,T,D(3),P(3)
REAL(EB), PARAMETER :: EPS=1.E-10_EB

IERR=0

! Schneider and Eberly, Section 11.1

D = P1-P0

E1 = V2-V1
E2 = V3-V1

CALL CROSS_PRODUCT(P,D,E2)

TMP = DOT_PRODUCT(P,E1)

IF ( ABS(TMP)<EPS ) RETURN

TMP = 1._EB/TMP
S = P0-V1

U = TMP*DOT_PRODUCT(S,P)
IF (U<0._EB .OR. U>1._EB) RETURN

CALL CROSS_PRODUCT(Q,S,E1)
V = TMP*DOT_PRODUCT(D,Q)
IF (V<0._EB .OR. (U+V)>1._EB) RETURN

T = TMP*DOT_PRODUCT(E2,Q)
!XI = P0 + T*D ! the intersection point

IF (T>=0._EB .AND. T<=1._EB) IERR=1

END SUBROUTINE LINE_SEGMENT_TRIANGLE_INTERSECT

! ---------------------------- LINE_PLANE_INTERSECT ----------------------------------------

SUBROUTINE LINE_PLANE_INTERSECT(IERR,P0,P1,PP,BB,IOR)
USE MATH_FUNCTIONS, ONLY: NORM2
IMPLICIT NONE

INTEGER, INTENT(OUT) :: IERR
REAL(EB), INTENT(IN) :: P0(3),P1(3),PP(4),BB(6)
INTEGER, INTENT(IN) :: IOR
REAL(EB) :: D(3),T,DENOM, Q0(3)
REAL(EB), PARAMETER :: EPS=1.E-10_EB

IERR=0
Q0=-999._EB
T=0._EB

D = P1-P0
DENOM = DOT_PRODUCT(PP(1:3),D)

IF (ABS(DENOM)>EPS) THEN
   T = -( DOT_PRODUCT(PP(1:3),P0)+PP(4) )/DENOM
   IF (T>=0._EB .AND. T<=1._EB) THEN
      Q0 = P0 + T*D ! instersection point
      IF (POINT_IN_BOX_2D(Q0,BB,IOR)) IERR=1
   ENDIF
ENDIF

END SUBROUTINE LINE_PLANE_INTERSECT

! ---------------------------- POINT_IN_BOX_2D ----------------------------------------

LOGICAL FUNCTION POINT_IN_BOX_2D(P,BB,IOR)
IMPLICIT NONE

REAL(EB), INTENT(IN) :: P(3),BB(6)
INTEGER, INTENT(IN) :: IOR

POINT_IN_BOX_2D=.FALSE.

SELECT CASE(ABS(IOR))
   CASE(1) ! YZ plane
      IF ( P(2)>=BB(3) .AND. P(2)<=BB(4) .AND. &
           P(3)>=BB(5) .AND. P(3)<=BB(6) ) POINT_IN_BOX_2D=.TRUE.
   CASE(2) ! XZ plane
      IF ( P(1)>=BB(1) .AND. P(1)<=BB(2) .AND. &
           P(3)>=BB(5) .AND. P(3)<=BB(6) ) POINT_IN_BOX_2D=.TRUE.
   CASE(3) ! XY plane
      IF ( P(1)>=BB(1) .AND. P(1)<=BB(2) .AND. &
           P(2)>=BB(3) .AND. P(2)<=BB(4) ) POINT_IN_BOX_2D=.TRUE.
END SELECT

END FUNCTION POINT_IN_BOX_2D

! ---------------------------- POINT_IN_TETRAHEDRON ----------------------------------------

LOGICAL FUNCTION POINT_IN_TETRAHEDRON(XP,V1,V2,V3,V4,BB)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT
IMPLICIT NONE

REAL(EB), INTENT(IN) :: XP(3),V1(3),V2(3),V3(3),V4(3),BB(6)
REAL(EB) :: U_VEC(3),V_VEC(3),N_VEC(3),Q_VEC(3),R_VEC(3)
INTEGER :: I

! In this routine, we test all four faces of the tet volume defined by the points X(i),Y(i),Z(i); i=1:4.
! If the point is on the negative side of all the faces, it is inside the volume.

POINT_IN_TETRAHEDRON=.FALSE.

! first test bounding box

IF (XP(1)<BB(1)) RETURN
IF (XP(1)>BB(2)) RETURN
IF (XP(2)<BB(3)) RETURN
IF (XP(2)>BB(4)) RETURN
IF (XP(3)<BB(5)) RETURN
IF (XP(3)>BB(6)) RETURN

POINT_IN_TETRAHEDRON=.TRUE.

FACE_LOOP: DO I=1,4

   SELECT CASE(I)
      CASE(1)
         ! vertex ordering = 1,2,3,4
         Q_VEC = XP-(/V1(1),V1(2),V1(3)/) ! form a vector from a point on the triangular surface to the point XP
         R_VEC = (/V4(1),V4(2),V4(3)/)-(/V1(1),V1(2),V1(3)/) ! vector from the tri to other point of volume defining inside
         U_VEC = (/V2(1)-V1(1),V2(2)-V1(2),V2(3)-V1(3)/) ! vectors forming the sides of the triangle
         V_VEC = (/V3(1)-V1(1),V3(2)-V1(2),V3(3)-V1(3)/)
      CASE(2)
         ! vertex ordering = 1,3,4,2
         Q_VEC = XP-(/V1(1),V1(2),V1(3)/)
         R_VEC = (/V2(1),V2(2),V2(3)/)-(/V1(1),V1(2),V1(3)/)
         U_VEC = (/V3(1)-V1(1),V3(2)-V1(2),V3(3)-V1(3)/)
         V_VEC = (/V4(1)-V1(1),V4(2)-V1(2),V4(3)-V1(3)/)
      CASE(3)
         ! vertex ordering = 1,4,2,3
         Q_VEC = XP-(/V1(1),V1(2),V1(3)/)
         R_VEC = (/V2(1),V2(2),V2(3)/)-(/V1(1),V1(2),V1(3)/)
         U_VEC = (/V4(1)-V1(1),V4(2)-V1(2),V4(3)-V1(3)/)
         V_VEC = (/V2(1)-V1(1),V2(2)-V1(2),V2(3)-V1(3)/)
      CASE(4)
         ! vertex ordering = 2,4,3,1
         Q_VEC = XP-(/V2(1),V2(2),V2(3)/)
         R_VEC = (/V1(1),V1(2),V1(3)/)-(/V2(1),V2(2),V2(3)/)
         U_VEC = (/V4(1)-V2(1),V4(2)-V2(2),V4(3)-V2(3)/)
         V_VEC = (/V3(1)-V2(1),V3(2)-V2(2),V3(3)-V2(3)/)
   END SELECT

   ! if the sign of the dot products are equal, the point is inside, else it is outside and we return

   IF ( ABS( SIGN(1._EB,DOT_PRODUCT(Q_VEC,N_VEC))-SIGN(1._EB,DOT_PRODUCT(R_VEC,N_VEC)) )>TWO_EPSILON_EB ) THEN
      POINT_IN_TETRAHEDRON=.FALSE.
      RETURN
   ENDIF

ENDDO FACE_LOOP

END FUNCTION POINT_IN_TETRAHEDRON

! ---------------------------- POINT_IN_POLYHEDRON ----------------------------------------

LOGICAL FUNCTION POINT_IN_POLYHEDRON(XP,BB)
IMPLICIT NONE

REAL(EB) :: XP(3),BB(6),XX(3),YY(3),ZZ(3),RAY_DIRECTION(3)
INTEGER :: I,J,N_INTERSECTIONS,IRAY
REAL(EB), PARAMETER :: EPS=1.E-6_EB

! Schneider and Eberly, Geometric Tools for Computer Graphics, Morgan Kaufmann, 2003. Section 13.4

POINT_IN_POLYHEDRON=.FALSE.

! test global bounding box

IF ( XP(1)<BB(1) .OR. XP(1)>BB(2) ) RETURN
IF ( XP(2)<BB(3) .OR. XP(2)>BB(4) ) RETURN
IF ( XP(3)<BB(5) .OR. XP(3)>BB(6) ) RETURN

N_INTERSECTIONS=0

RAY_DIRECTION = (/0._EB,0._EB,1._EB/)

FACE_LOOP: DO I=1,N_FACE

   ! test bounding box
   XX(1) = VERTEX(FACET(I)%VERTEX(1))%X
   XX(2) = VERTEX(FACET(I)%VERTEX(2))%X
   XX(3) = VERTEX(FACET(I)%VERTEX(3))%X

   IF (XP(1)<MINVAL(XX)) CYCLE FACE_LOOP
   IF (XP(1)>MAXVAL(XX)) CYCLE FACE_LOOP

   YY(1) = VERTEX(FACET(I)%VERTEX(1))%Y
   YY(2) = VERTEX(FACET(I)%VERTEX(2))%Y
   YY(3) = VERTEX(FACET(I)%VERTEX(3))%Y

   IF (XP(2)<MINVAL(YY)) CYCLE FACE_LOOP
   IF (XP(2)>MAXVAL(YY)) CYCLE FACE_LOOP

   ZZ(1) = VERTEX(FACET(I)%VERTEX(1))%Z
   ZZ(2) = VERTEX(FACET(I)%VERTEX(2))%Z
   ZZ(3) = VERTEX(FACET(I)%VERTEX(3))%Z

   IF (XP(3)>MAXVAL(ZZ)) CYCLE FACE_LOOP

   RAY_TEST_LOOP: DO J=1,3
      IRAY = RAY_TRIANGLE_INTERSECT(I,XP,RAY_DIRECTION)
      SELECT CASE(IRAY)
         CASE(0)
            ! does not intersect
            EXIT RAY_TEST_LOOP
         CASE(1)
            ! ray intersects triangle
            N_INTERSECTIONS=N_INTERSECTIONS+1
            EXIT RAY_TEST_LOOP
         CASE(2)
            ! ray intersects edge, try new ray (shift origin)
            IF (J==1) XP=XP+(/EPS,0._EB,0._EB/) ! shift in x direction
            IF (J==2) XP=XP+(/0._EB,EPS,0._EB/) ! shift in y direction
            IF (J==3) WRITE(LU_ERR,*) 'WARNING: ray test failed'
      END SELECT
   ENDDO RAY_TEST_LOOP

ENDDO FACE_LOOP

IF ( MOD(N_INTERSECTIONS,2)/=0 ) POINT_IN_POLYHEDRON=.TRUE.

END FUNCTION POINT_IN_POLYHEDRON

! ---------------------------- POINT_IN_TRIANGLE ----------------------------------------

LOGICAL FUNCTION POINT_IN_TRIANGLE(P,V1,V2,V3)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT
IMPLICIT NONE

REAL(EB), INTENT(IN) :: P(3),V1(3),V2(3),V3(3)
REAL(EB) :: E(3),E1(3),E2(3),N(3),R(3),Q(3)
INTEGER :: I
REAL(EB), PARAMETER :: EPS=1.E-16_EB

! This routine tests whether the projection of P, in the plane normal
! direction, onto to the plane defined by the triangle (V1,V2,V3) is
! inside the triangle.

POINT_IN_TRIANGLE=.TRUE. ! start by assuming the point is inside

! compute face normal
E1 = V2-V1
E2 = V3-V1
CALL CROSS_PRODUCT(N,E1,E2)

EDGE_LOOP: DO I=1,3
   SELECT CASE(I)
      CASE(1)
         E = V2-V1
         R = P-V1
      CASE(2)
         E = V3-V2
         R = P-V2
      CASE(3)
         E = V1-V3
         R = P-V3
   END SELECT
   CALL CROSS_PRODUCT(Q,E,R)
   IF ( DOT_PRODUCT(Q,N) < -EPS ) THEN
      POINT_IN_TRIANGLE=.FALSE.
      RETURN
   ENDIF
ENDDO EDGE_LOOP

END FUNCTION POINT_IN_TRIANGLE

! ---------------------------- RAY_TRIANGLE_INTERSECT ----------------------------------------

INTEGER FUNCTION RAY_TRIANGLE_INTERSECT(TRI,XP,D)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT
IMPLICIT NONE

INTEGER, INTENT(IN) :: TRI
REAL(EB), INTENT(IN) :: XP(3),D(3)
REAL(EB) :: E1(3),E2(3),P(3),S(3),Q(3),U,V,TMP,V1(3),V2(3),V3(3),T !,XI(3)
REAL(EB), PARAMETER :: EPS=1.E-10_EB

! Schneider and Eberly, Section 11.1

V1(1) = VERTEX(FACET(TRI)%VERTEX(1))%X
V1(2) = VERTEX(FACET(TRI)%VERTEX(1))%Y
V1(3) = VERTEX(FACET(TRI)%VERTEX(1))%Z

V2(1) = VERTEX(FACET(TRI)%VERTEX(2))%X
V2(2) = VERTEX(FACET(TRI)%VERTEX(2))%Y
V2(3) = VERTEX(FACET(TRI)%VERTEX(2))%Z

V3(1) = VERTEX(FACET(TRI)%VERTEX(3))%X
V3(2) = VERTEX(FACET(TRI)%VERTEX(3))%Y
V3(3) = VERTEX(FACET(TRI)%VERTEX(3))%Z

E1 = V2-V1
E2 = V3-V1

CALL CROSS_PRODUCT(P,D,E2)

TMP = DOT_PRODUCT(P,E1)

IF ( ABS(TMP)<EPS ) THEN
   RAY_TRIANGLE_INTERSECT=0
   RETURN
ENDIF

TMP = 1._EB/TMP
S = XP-V1

U = TMP*DOT_PRODUCT(S,P)
IF (U<-EPS .OR. U>(1._EB+EPS)) THEN
   ! ray does not intersect triangle
   RAY_TRIANGLE_INTERSECT=0
   RETURN
ENDIF

IF (U<EPS .OR. U>(1._EB-EPS)) THEN
   ! ray intersects edge
   RAY_TRIANGLE_INTERSECT=2
   RETURN
ENDIF

CALL CROSS_PRODUCT(Q,S,E1)
V = TMP*DOT_PRODUCT(D,Q)
IF (V<-EPS .OR. (U+V)>(1._EB+EPS)) THEN
   ! ray does not intersect triangle
   RAY_TRIANGLE_INTERSECT=0
   RETURN
ENDIF

IF (V<EPS .OR. (U+V)>(1._EB-EPS)) THEN
   ! ray intersects edge
   RAY_TRIANGLE_INTERSECT=2
   RETURN
ENDIF

T = TMP*DOT_PRODUCT(E2,Q)
!XI = XP + T*D ! the intersection point

IF (T>0._EB) THEN
   RAY_TRIANGLE_INTERSECT=1
ELSE
   RAY_TRIANGLE_INTERSECT=0
ENDIF
RETURN

END FUNCTION RAY_TRIANGLE_INTERSECT

! ---------------------------- TRILINEAR ----------------------------------------

REAL(EB) FUNCTION TRILINEAR(UU,DXI,LL)
IMPLICIT NONE

REAL(EB), INTENT(IN) :: UU(0:1,0:1,0:1),DXI(3),LL(3)
REAL(EB) :: XX,YY,ZZ

! Comments:
!
! see http://local.wasp.uwa.edu.au/~pbourke/miscellaneous/interpolation/index.html
! with appropriate scaling. LL is length of side.
!
!                       UU(1,1,1)
!        z /----------/
!        ^/          / |
!        ------------  |    Particle position
!        |          |  |
!  LL(3) |   o<-----|------- DXI = [DXI(1),DXI(2),DXI(3)]
!        |          | /        
!        |          |/      Particle property at XX = TRILINEAR
!        ------------> x
!        ^
!        |
!   X0 = [0,0,0]
!
!    UU(0,0,0)
!
!===========================================================

XX = DXI(1)/LL(1)
YY = DXI(2)/LL(2)
ZZ = DXI(3)/LL(3)

TRILINEAR = UU(0,0,0)*(1._EB-XX)*(1._EB-YY)*(1._EB-ZZ) + &
            UU(1,0,0)*XX*(1._EB-YY)*(1._EB-ZZ) +         & 
            UU(0,1,0)*(1._EB-XX)*YY*(1._EB-ZZ) +         &
            UU(0,0,1)*(1._EB-XX)*(1._EB-YY)*ZZ +         &
            UU(1,0,1)*XX*(1._EB-YY)*ZZ +                 &
            UU(0,1,1)*(1._EB-XX)*YY*ZZ +                 &
            UU(1,1,0)*XX*YY*(1._EB-ZZ) +                 & 
            UU(1,1,1)*XX*YY*ZZ

END FUNCTION TRILINEAR

! ---------------------------- GETU ----------------------------------------

SUBROUTINE GETU(U_DATA,DXI,XI_IN,I_VEL,NM)
IMPLICIT NONE

REAL(EB), INTENT(OUT) :: U_DATA(0:1,0:1,0:1),DXI(3)
REAL(EB), INTENT(IN) :: XI_IN(3)
INTEGER, INTENT(IN) :: I_VEL,NM
TYPE(MESH_TYPE), POINTER :: M
REAL(EB), POINTER, DIMENSION(:,:,:) :: UU,VV,WW
INTEGER :: II,JJ,KK
REAL(EB) :: XI(3)

M=>MESHES(NM)
IF (PREDICTOR) THEN
   UU => M%U
   VV => M%V
   WW => M%W
ELSE
   UU => M%US
   VV => M%VS
   WW => M%WS
ENDIF

!II = INDU(1)
!JJ = INDU(2)
!KK = INDU(3)
!
!IF (XI(1)<XU(1)) THEN
!   N=CEILING((XU(1)-XI(1))/M%DX(II))
!   II=MAX(0,II-N)
!   DXI(1)=XI(1)-(XU(1)-REAL(N,EB)*M%DX(II))
!ELSE
!   N=FLOOR((XI(1)-XU(1))/M%DX(II))
!   II=MIN(IBP1,II+N)
!   DXI(1)=XI(1)-(XU(1)+REAL(N,EB)*M%DX(II))
!ENDIF
!
!IF (XI(2)<XU(2)) THEN
!   N=CEILING((XU(2)-XI(2))/M%DY(JJ))
!   JJ=MAX(0,JJ-N)
!   DXI(2)=XI(2)-(XU(2)-REAL(N,EB)*M%DY(JJ))
!ELSE
!   N=FLOOR((XI(2)-XU(2))/M%DY(JJ))
!   JJ=MIN(JBP1,JJ+N)
!   DXI(2)=XI(2)-(XU(2)+REAL(N,EB)*M%DY(JJ))
!ENDIF
!
!IF (XI(3)<XU(3)) THEN
!   N=CEILING((XU(3)-XI(3))/M%DZ(KK))
!   KK=MAX(0,KK-N)
!   DXI(3)=XI(3)-(XU(3)-REAL(N,EB)*M%DZ(KK))
!ELSE
!   N=FLOOR((XI(3)-XU(3))/M%DZ(KK))
!   KK=MIN(KBP1,KK+N)
!   DXI(3)=XI(3)-(XU(3)+REAL(N,EB)*M%DZ(KK))
!ENDIF

XI(1) = MAX(M%XS,MIN(M%XF,XI_IN(1)))
XI(2) = MAX(M%YS,MIN(M%YF,XI_IN(2)))
XI(3) = MAX(M%ZS,MIN(M%ZF,XI_IN(3)))

SELECT CASE(I_VEL)
   CASE(1)
      II = FLOOR((XI(1)-M%XS)/M%DX(1))
      JJ = FLOOR((XI(2)-M%YS)/M%DY(1)+0.5_EB)
      KK = FLOOR((XI(3)-M%ZS)/M%DZ(1)+0.5_EB)
      DXI(1) = XI(1) - M%X(II)
      DXI(2) = XI(2) - M%YC(JJ)
      DXI(3) = XI(3) - M%ZC(KK)
   CASE(2)
      II = FLOOR((XI(1)-M%XS)/M%DX(1)+0.5_EB)
      JJ = FLOOR((XI(2)-M%YS)/M%DY(1))
      KK = FLOOR((XI(3)-M%ZS)/M%DZ(1)+0.5_EB)
      DXI(1) = XI(1) - M%XC(II)
      DXI(2) = XI(2) - M%Y(JJ)
      DXI(3) = XI(3) - M%ZC(KK)
   CASE(3)
      II = FLOOR((XI(1)-M%XS)/M%DX(1)+0.5_EB)
      JJ = FLOOR((XI(2)-M%YS)/M%DY(1)+0.5_EB)
      KK = FLOOR((XI(3)-M%ZS)/M%DZ(1))
      DXI(1) = XI(1) - M%XC(II)
      DXI(2) = XI(2) - M%YC(JJ)
      DXI(3) = XI(3) - M%Z(KK)
   CASE(4)
      II = FLOOR((XI(1)-M%XS)/M%DX(1)+0.5_EB)
      JJ = FLOOR((XI(2)-M%YS)/M%DY(1)+0.5_EB)
      KK = FLOOR((XI(3)-M%ZS)/M%DZ(1)+0.5_EB)
      DXI(1) = XI(1) - M%XC(II)
      DXI(2) = XI(2) - M%YC(JJ)
      DXI(3) = XI(3) - M%ZC(KK)
END SELECT

DXI = MAX(0._EB,DXI)

SELECT CASE(I_VEL)
   CASE(1)
      U_DATA(0,0,0) = UU(II,JJ,KK)
      U_DATA(1,0,0) = UU(II+1,JJ,KK)
      U_DATA(0,1,0) = UU(II,JJ+1,KK)
      U_DATA(0,0,1) = UU(II,JJ,KK+1)
      U_DATA(1,0,1) = UU(II+1,JJ,KK+1)
      U_DATA(0,1,1) = UU(II,JJ+1,KK+1)
      U_DATA(1,1,0) = UU(II+1,JJ+1,KK)
      U_DATA(1,1,1) = UU(II+1,JJ+1,KK+1)
   CASE(2)
      U_DATA(0,0,0) = VV(II,JJ,KK)
      U_DATA(1,0,0) = VV(II+1,JJ,KK)
      U_DATA(0,1,0) = VV(II,JJ+1,KK)
      U_DATA(0,0,1) = VV(II,JJ,KK+1)
      U_DATA(1,0,1) = VV(II+1,JJ,KK+1)
      U_DATA(0,1,1) = VV(II,JJ+1,KK+1)
      U_DATA(1,1,0) = VV(II+1,JJ+1,KK)
      U_DATA(1,1,1) = VV(II+1,JJ+1,KK+1)
   CASE(3)
      U_DATA(0,0,0) = WW(II,JJ,KK)
      U_DATA(1,0,0) = WW(II+1,JJ,KK)
      U_DATA(0,1,0) = WW(II,JJ+1,KK)
      U_DATA(0,0,1) = WW(II,JJ,KK+1)
      U_DATA(1,0,1) = WW(II+1,JJ,KK+1)
      U_DATA(0,1,1) = WW(II,JJ+1,KK+1)
      U_DATA(1,1,0) = WW(II+1,JJ+1,KK)
      U_DATA(1,1,1) = WW(II+1,JJ+1,KK+1)
   CASE(4) ! viscosity
      U_DATA(0,0,0) = M%MU(II,JJ,KK)
      U_DATA(1,0,0) = M%MU(II+1,JJ,KK)
      U_DATA(0,1,0) = M%MU(II,JJ+1,KK)
      U_DATA(0,0,1) = M%MU(II,JJ,KK+1)
      U_DATA(1,0,1) = M%MU(II+1,JJ,KK+1)
      U_DATA(0,1,1) = M%MU(II,JJ+1,KK+1)
      U_DATA(1,1,0) = M%MU(II+1,JJ+1,KK)
      U_DATA(1,1,1) = M%MU(II+1,JJ+1,KK+1)
END SELECT

END SUBROUTINE GETU

! ---------------------------- GETGRAD ----------------------------------------

SUBROUTINE GETGRAD(G_DATA,DXI,XI,XU,INDU,COMP_I,COMP_J,NM)
IMPLICIT NONE

REAL(EB), INTENT(OUT) :: G_DATA(0:1,0:1,0:1),DXI(3)
REAL(EB), INTENT(IN) :: XI(3),XU(3)
INTEGER, INTENT(IN) :: INDU(3),COMP_I,COMP_J,NM
TYPE(MESH_TYPE), POINTER :: M
REAL(EB), POINTER, DIMENSION(:,:,:) :: DUDX
INTEGER :: II,JJ,KK,N
CHARACTER(MESSAGE_LENGTH) :: MESSAGE

M=>MESHES(NM)

IF (COMP_I==1 .AND. COMP_J==1) DUDX => M%WORK5
IF (COMP_I==1 .AND. COMP_J==2) DUDX => M%IBM_SAVE1
IF (COMP_I==1 .AND. COMP_J==3) DUDX => M%IBM_SAVE2
IF (COMP_I==2 .AND. COMP_J==1) DUDX => M%IBM_SAVE3
IF (COMP_I==2 .AND. COMP_J==2) DUDX => M%WORK6
IF (COMP_I==2 .AND. COMP_J==3) DUDX => M%IBM_SAVE4
IF (COMP_I==3 .AND. COMP_J==1) DUDX => M%IBM_SAVE5
IF (COMP_I==3 .AND. COMP_J==2) DUDX => M%IBM_SAVE6
IF (COMP_I==3 .AND. COMP_J==3) DUDX => M%WORK7

II = INDU(1)
JJ = INDU(2)
KK = INDU(3)

IF (XI(1)<XU(1)) THEN
   N=CEILING((XU(1)-XI(1))/M%DX(II))
   II=MAX(0,II-N)
   DXI(1)=XI(1)-(XU(1)-REAL(N,EB)*M%DX(II))
ELSE
   N=FLOOR((XI(1)-XU(1))/M%DX(II))
   II=MIN(IBP1,II+N)
   DXI(1)=XI(1)-(XU(1)+REAL(N,EB)*M%DX(II))
ENDIF

IF (XI(2)<XU(2)) THEN
   N=CEILING((XU(2)-XI(2))/M%DY(JJ))
   JJ=MAX(0,JJ-N)
   DXI(2)=XI(2)-(XU(2)-REAL(N,EB)*M%DY(JJ))
ELSE
   N=FLOOR((XI(2)-XU(2))/M%DY(JJ))
   JJ=MIN(JBP1,JJ+N)
   DXI(2)=XI(2)-(XU(2)+REAL(N,EB)*M%DY(JJ))
ENDIF

IF (XI(3)<XU(3)) THEN
   N=CEILING((XU(3)-XI(3))/M%DZ(KK))
   KK=MAX(0,KK-N)
   DXI(3)=XI(3)-(XU(3)-REAL(N,EB)*M%DZ(KK))
ELSE
   N=FLOOR((XI(3)-XU(3))/M%DZ(KK))
   KK=MIN(KBP1,KK+N)
   DXI(3)=XI(3)-(XU(3)+REAL(N,EB)*M%DZ(KK))
ENDIF

IF (ANY(DXI<0._EB)) THEN
   WRITE(MESSAGE,'(A)') 'ERROR: DXI<0 in GETGRAD'
   CALL SHUTDOWN(MESSAGE)
ENDIF
IF (DXI(1)>M%DX(II) .OR. DXI(2)>M%DY(JJ) .OR. DXI(3)>M%DZ(KK)) THEN
   WRITE(MESSAGE,'(A)') 'ERROR: DXI>DX in GETGRAD'
   CALL SHUTDOWN(MESSAGE)
ENDIF

G_DATA(0,0,0) = DUDX(II,JJ,KK)
G_DATA(1,0,0) = DUDX(II+1,JJ,KK)
G_DATA(0,1,0) = DUDX(II,JJ+1,KK)
G_DATA(0,0,1) = DUDX(II,JJ,KK+1)
G_DATA(1,0,1) = DUDX(II+1,JJ,KK+1)
G_DATA(0,1,1) = DUDX(II,JJ+1,KK+1)
G_DATA(1,1,0) = DUDX(II+1,JJ+1,KK)
G_DATA(1,1,1) = DUDX(II+1,JJ+1,KK+1)

END SUBROUTINE GETGRAD

! ---------------------------- GET_VELO_IBM ----------------------------------------

SUBROUTINE GET_VELO_IBM(VELO_IBM,U_VELO,IERR,VELO_INDEX,XVELO,TRI_INDEX,IBM_INDEX,DXC,NM)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT,NORM2
IMPLICIT NONE

REAL(EB), INTENT(OUT) :: VELO_IBM
INTEGER, INTENT(OUT) :: IERR
REAL(EB), INTENT(IN) :: XVELO(3),DXC(3),U_VELO(3)
INTEGER, INTENT(IN) :: VELO_INDEX,TRI_INDEX,IBM_INDEX,NM
REAL(EB) :: NN(3),R(3),V1(3),V2(3),V3(3),T,U_DATA(0:1,0:1,0:1),XI(3),DXI(3),C(3,3),SS(3),PP(3),U_STRM,U_ORTH,U_NORM,KE
REAL(EB), PARAMETER :: EPS=1.E-10_EB
! Cartesian grid coordinate system orthonormal basis vectors
REAL(EB), DIMENSION(3), PARAMETER :: E1=(/1._EB,0._EB,0._EB/),E2=(/0._EB,1._EB,0._EB/),E3=(/0._EB,0._EB,1._EB/)

IERR=0
VELO_IBM=0._EB

V1 = (/VERTEX(FACET(TRI_INDEX)%VERTEX(1))%X,VERTEX(FACET(TRI_INDEX)%VERTEX(1))%Y,VERTEX(FACET(TRI_INDEX)%VERTEX(1))%Z/)
V2 = (/VERTEX(FACET(TRI_INDEX)%VERTEX(2))%X,VERTEX(FACET(TRI_INDEX)%VERTEX(2))%Y,VERTEX(FACET(TRI_INDEX)%VERTEX(2))%Z/)
V3 = (/VERTEX(FACET(TRI_INDEX)%VERTEX(3))%X,VERTEX(FACET(TRI_INDEX)%VERTEX(3))%Y,VERTEX(FACET(TRI_INDEX)%VERTEX(3))%Z/)
NN = FACET(TRI_INDEX)%NVEC

R = XVELO-V1
IF ( NORM2(R)<EPS ) R = XVELO-V2 ! select a different vertex

T = DOT_PRODUCT(R,NN)

IF (IBM_INDEX==0 .AND. T<EPS) RETURN ! the velocity point is on or interior to the surface

IF (IBM_INDEX==1) THEN
   XI = XVELO + T*NN
   CALL GETU(U_DATA,DXI,XI,VELO_INDEX,NM)
   VELO_IBM = 0.5_EB*TRILINEAR(U_DATA,DXI,DXC)
   RETURN
ENDIF

IF (IBM_INDEX==2) THEN

   ! find a vector PP in the tangent plane of the surface and orthogonal to U_VELO
   CALL CROSS_PRODUCT(PP,NN,U_VELO) ! PP = NN x U_VELO
   IF (ABS(NORM2(PP))<=TWO_EPSILON_EB) THEN
      ! tangent vector is completely arbitrary, just perpendicular to NN
      IF (ABS(NN(1))>=TWO_EPSILON_EB .OR.  ABS(NN(2))>=TWO_EPSILON_EB) PP = (/NN(2),-NN(1),0._EB/)
      IF (ABS(NN(1))<=TWO_EPSILON_EB .AND. ABS(NN(2))<=TWO_EPSILON_EB) PP = (/NN(3),0._EB,-NN(1)/)
   ENDIF
   PP = PP/NORM2(PP) ! normalize to unit vector
   CALL CROSS_PRODUCT(SS,PP,NN) ! define the streamwise unit vector SS

   !! check unit normal vectors
   !print *,DOT_PRODUCT(SS,SS) ! should be 1
   !print *,DOT_PRODUCT(SS,PP) ! should be 0
   !print *,DOT_PRODUCT(SS,NN) ! should be 0
   !print *,DOT_PRODUCT(PP,PP) ! should be 1
   !print *,DOT_PRODUCT(PP,NN) ! should be 0
   !print *,DOT_PRODUCT(NN,NN) ! should be 1
   !print *                    ! blank line

   ! directional cosines (see Pope, Eq. A.11)
   C(1,1) = DOT_PRODUCT(E1,SS)
   C(1,2) = DOT_PRODUCT(E1,PP)
   C(1,3) = DOT_PRODUCT(E1,NN)
   C(2,1) = DOT_PRODUCT(E2,SS)
   C(2,2) = DOT_PRODUCT(E2,PP)
   C(2,3) = DOT_PRODUCT(E2,NN)
   C(3,1) = DOT_PRODUCT(E3,SS)
   C(3,2) = DOT_PRODUCT(E3,PP)
   C(3,3) = DOT_PRODUCT(E3,NN)

   ! transform velocity (see Pope, Eq. A.17)
   U_STRM = C(1,1)*U_VELO(1) + C(2,1)*U_VELO(2) + C(3,1)*U_VELO(3)
   U_ORTH = C(1,2)*U_VELO(1) + C(2,2)*U_VELO(2) + C(3,2)*U_VELO(3)
   U_NORM = C(1,3)*U_VELO(1) + C(2,3)*U_VELO(2) + C(3,3)*U_VELO(3)

   !! check U_ORTH, should be zero
   !print *, U_ORTH

   KE = 0.5_EB*(U_STRM**2 + U_NORM**2)

   ! here's a crude model: set U_NORM to zero
   U_NORM = 0._EB
   U_STRM = 0.5_EB*SQRT(2._EB*KE)

   ! transform velocity back to Cartesian component I_VEL
   VELO_IBM = C(VELO_INDEX,1)*U_STRM + C(VELO_INDEX,3)*U_NORM
   RETURN
ENDIF

IERR=1

END SUBROUTINE GET_VELO_IBM

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! Cut-cell subroutines by Charles Luo
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

! ---------------------------- TRI_PLANE_BOX_INTERSECT ----------------------------------------

SUBROUTINE TRI_PLANE_BOX_INTERSECT(NP,PC,V1,V2,V3,BB)
USE MATH_FUNCTIONS
IMPLICIT NONE
! get the intersection points (cooridnates) of the BB's 12 edges and the plane of the trianlge
! regular intersection polygons with 0, 3, 4, 5, or 6 corners
! irregular intersection case (corner, edge, or face intersection) should also be ok.

INTEGER, INTENT(OUT) :: NP
REAL(EB), INTENT(OUT) :: PC(18) ! max 6 points but maybe repeated at the vertices
REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3),BB(6)
REAL(EB) :: P0(3),P1(3),Q(3),PC_TMP(60)
INTEGER :: I,J,IERR,IERR2

NP = 0
EDGE_LOOP: DO I=1,12
   SELECT CASE(I) 
      CASE(1)
         P0(1)=BB(1)
         P0(2)=BB(3)
         P0(3)=BB(5)
         P1(1)=BB(2)
         P1(2)=BB(3)
         P1(3)=BB(5)
      CASE(2)
         P0(1)=BB(2)
         P0(2)=BB(3)
         P0(3)=BB(5)
         P1(1)=BB(2)
         P1(2)=BB(4)
         P1(3)=BB(5)
      CASE(3)
         P0(1)=BB(2)
         P0(2)=BB(4)
         P0(3)=BB(5)
         P1(1)=BB(1)
         P1(2)=BB(4)
         P1(3)=BB(5)
      CASE(4)
         P0(1)=BB(1)
         P0(2)=BB(4)
         P0(3)=BB(5)
         P1(1)=BB(1)
         P1(2)=BB(3)
         P1(3)=BB(5)
      CASE(5)
         P0(1)=BB(1)
         P0(2)=BB(3)
         P0(3)=BB(6)
         P1(1)=BB(2)
         P1(2)=BB(3)
         P1(3)=BB(6)
      CASE(6)
         P0(1)=BB(2)
         P0(2)=BB(3)
         P0(3)=BB(6)
         P1(1)=BB(2)
         P1(2)=BB(4)
         P1(3)=BB(6)
      CASE(7)
         P0(1)=BB(2)
         P0(2)=BB(4)
         P0(3)=BB(6)
         P1(1)=BB(1)
         P1(2)=BB(4)
         P1(3)=BB(6)
      CASE(8)
         P0(1)=BB(1)
         P0(2)=BB(4)
         P0(3)=BB(6)
         P1(1)=BB(1)
         P1(2)=BB(3)
         P1(3)=BB(6)
      CASE(9)
         P0(1)=BB(1)
         P0(2)=BB(3)
         P0(3)=BB(5)
         P1(1)=BB(1)
         P1(2)=BB(3)
         P1(3)=BB(6)
      CASE(10)
         P0(1)=BB(2)
         P0(2)=BB(3)
         P0(3)=BB(5)
         P1(1)=BB(2)
         P1(2)=BB(3)
         P1(3)=BB(6)
      CASE(11)
         P0(1)=BB(2)
         P0(2)=BB(4)
         P0(3)=BB(5)
         P1(1)=BB(2)
         P1(2)=BB(4)
         P1(3)=BB(6)
      CASE(12)
         P0(1)=BB(1)
         P0(2)=BB(4)
         P0(3)=BB(5)
         P1(1)=BB(1)
         P1(2)=BB(4)
         P1(3)=BB(6)
   END SELECT 
   CALL LINE_SEG_TRI_PLANE_INTERSECT(IERR,IERR2,Q,V1,V2,V3,P0,P1)
    
   IF (IERR==1) THEN
      NP=NP+1
      DO J=1,3
         PC_TMP((NP-1)*3+J)=Q(J)
      ENDDO
   ENDIF
ENDDO EDGE_LOOP

! For more than 3 intersection points
! they have to be sorted in order to create a convex polygon
CALL ELIMATE_REPEATED_POINTS(NP,PC_TMP)
IF ( NP > 6) THEN
   WRITE(LU_OUTPUT,*)"*** Triangle box intersections"
   DO I = 1, NP
      WRITE(LU_OUTPUT,*)I,PC_TMP(3*I-2),PC_TMP(3*I-1),PC_TMP(3*I)
   ENDDO
   CALL SHUTDOWN("ERROR: more than 6 triangle box intersections")
ENDIF
IF (NP > 3) THEN 
   CALL SORT_POLYGON_CORNERS(NP,V1,V2,V3,PC_TMP)
ENDIF
DO I=1,NP*3
   PC(I) = PC_TMP(I)
ENDDO

RETURN
END SUBROUTINE TRI_PLANE_BOX_INTERSECT

! ---------------------------- SORT_POLYGON_CORNERS ----------------------------------------

SUBROUTINE SORT_POLYGON_CORNERS(NP,V1,V2,V3,PC)
USE MATH_FUNCTIONS, ONLY: CROSS_PRODUCT
IMPLICIT NONE
! Sort all the corners of a polygon
! Ref: Gernot Hoffmann, Cube Plane Intersection.

INTEGER, INTENT(IN) :: NP
REAL(EB), INTENT(INOUT) :: PC(60)
REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3)
REAL(EB) :: MEAN_VALUE(3),POLY_NORM(3),R1,R2,TMP(3),U(3),W(3)
INTEGER :: I,J,K,IOR,NA,NB

IF (NP <=3 ) RETURN

U = V2-V1
W = V3-V1
CALL CROSS_PRODUCT(POLY_NORM,U,W)

DO I=1,3
   MEAN_VALUE(I) = 0._EB
   DO J=1,NP
      MEAN_VALUE(I) = MEAN_VALUE(I) + PC((J-1)*3+I)/REAL(NP)
   ENDDO
ENDDO

!get normal of ploygan 
IF (ABS(POLY_NORM(1)) >= ABS(POLY_NORM(2)) .AND. ABS(POLY_NORM(1)) >= ABS(POLY_NORM(3)) ) THEN
   IOR = 1
   NA = 2
   NB = 3
ELSE IF (ABS(POLY_NORM(2)) >= ABS(POLY_NORM(3)) ) THEN
   IOR = 2
   NA = 1
   NB = 3
ELSE
   IOR = 3
   NA = 1
   NB = 2
ENDIF

DO I=1,NP-1
   R1 = ATAN2(PC((I-1)*3+NB)-MEAN_VALUE(NB), PC((I-1)*3+NA)-MEAN_VALUE(NA))
   DO J=I+1, NP
      R2 = ATAN2(PC((J-1)*3+NB)-MEAN_VALUE(NB), PC((J-1)*3+NA)-MEAN_VALUE(NA))
      IF (R2 < R1) THEN
         DO K=1,3
            TMP(K) = PC((J-1)*3+K)
            PC((J-1)*3+K) = PC((I-1)*3+K)
            PC((I-1)*3+K) = TMP(K)
            R1 = R2
         ENDDO
      ENDIF
   ENDDO
ENDDO
    
RETURN
END SUBROUTINE SORT_POLYGON_CORNERS

! ---------------------------- TRIANGLE_POLYGON_POINTS ----------------------------------------

SUBROUTINE TRIANGLE_POLYGON_POINTS(IERR,NXP,XPC,V1,V2,V3,NP,PC,BB)
IMPLICIT NONE
! Calculate the intersection points of a triangle and a polygon, if intersected.
! http://softsurfer.com/Archive/algorithm_0106/algorithm_0106.htm

INTEGER, INTENT(IN) :: NP
INTEGER, INTENT(OUT) :: NXP,IERR
REAL(EB), INTENT(OUT) :: XPC(60)
REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3),PC(18),BB(6)
INTEGER :: I,J,K
REAL(EB) :: U(3),V(3),W(3),S1P0(3),XC(3)
REAL(EB) :: A,B,C,D,E,DD,SC,TC
REAL(EB), PARAMETER :: EPS=1.E-20_EB,TOL=1.E-12_EB
!LOGICAL :: POINT_IN_BB, POINT_IN_TRIANGLE

IERR = 0
SC = 0._EB
TC = 0._EB
NXP = 0
TRIANGLE_LOOP: DO I=1,3
   SELECT CASE(I)
      CASE(1)
         U = V2-V1
         S1P0 = V1
      CASE(2)
         U = V3-V2
         S1P0 = V2
      CASE(3)
         U = V1-V3
         S1P0 = V3
   END SELECT
    
   POLYGON_LOOP: DO J=1,NP
      IF (J < NP) THEN
         DO K=1,3
            V(K) = PC(J*3+K)-PC((J-1)*3+K)
         ENDDO
      ELSE
         DO K=1,3
            V(K) = PC(K)-PC((J-1)*3+K)
         ENDDO
      ENDIF
        
      DO K=1,3
         W(K) = S1P0(K)-PC((J-1)*3+K)
      ENDDO
        
      A = DOT_PRODUCT(U,U)
      B = DOT_PRODUCT(U,V)
      C = DOT_PRODUCT(V,V)
      D = DOT_PRODUCT(U,W)
      E = DOT_PRODUCT(V,W)
      DD = A*C-B*B
        
      IF (DD < EPS) THEN ! almost parallel
         IERR = 0
         CYCLE
      ELSE 
         SC = (B*E-C*D)/DD
         TC = (A*E-B*D)/DD
         IF (SC>-TOL .AND. SC<1._EB+TOL .AND. TC>-TOL .AND. TC<1._EB+TOL ) THEN
            NXP = NXP+1
            XC = S1P0+SC*U
            DO K=1,3
               XPC((NXP-1)*3+K) = XC(K)
            ENDDO
         ENDIF
      ENDIF
                
   ENDDO POLYGON_LOOP
ENDDO TRIANGLE_LOOP

!WRITE(LU_ERR,*) 'A', NXP
! add triangle vertices in polygon
DO I=1,3
   SELECT CASE(I)
      CASE(1)
         V = V1
      CASE(2)
         V = V2
      CASE(3)
         V = V3
   END SELECT
    
   IF (POINT_IN_BB(V,BB)) THEN
      NXP = NXP+1
      DO K=1,3
         XPC((NXP-1)*3+K) = V(K)
      ENDDO
   ENDIF
ENDDO

!WRITE(LU_ERR,*) 'B', NXP
! add polygon vertices in triangle
DO I=1,NP
   DO J=1,3
      V(J) = PC((I-1)*3+J)
   ENDDO
   IF (POINT_IN_TRIANGLE(V,V1,V2,V3)) THEN
      NXP = NXP+1
      DO J=1,3
         XPC((NXP-1)*3+J) = V(J)
      ENDDO
   ENDIF
ENDDO

!WRITE(LU_ERR,*) 'C', NXP

CALL ELIMATE_REPEATED_POINTS(NXP,XPC)

!WRITE(LU_ERR,*) 'D', NXP

IF (NXP > 3) THEN 
   CALL SORT_POLYGON_CORNERS(NXP,V1,V2,V3,XPC)
ENDIF

!WRITE(LU_ERR,*) 'E', NXP

IF (NXP >= 1) THEN
   IERR = 1 ! index for intersecting
ELSE
   IERR = 0
ENDIF

RETURN
END SUBROUTINE TRIANGLE_POLYGON_POINTS

! ---------------------------- ELIMATE_REPEATED_POINTS ----------------------------------------

SUBROUTINE ELIMATE_REPEATED_POINTS(NP,PC)
USE MATH_FUNCTIONS, ONLY:NORM2
IMPLICIT NONE

INTEGER, INTENT(INOUT):: NP
REAL(EB), INTENT(INOUT) :: PC(60)
INTEGER :: NP2,I,J,K
REAL(EB) :: U(3),V(3),W(3)
REAL(EB), PARAMETER :: EPS_DIFF=1.0E-8_EB

I = 1
DO WHILE (I <= NP-1)
   DO K=1,3
      U(K) = PC(3*(I-1)+K)
   ENDDO
    
   J = I+1
   NP2 = NP
   DO WHILE (J <= NP2)
      DO K=1,3
         V(K) = PC(3*(J-1)+K)
      ENDDO
      W = U-V
      ! use hybrid comparison test
      !    absolute for small values
      !    relative for large values
      IF (NORM2(W) <= MAX(1.0_EB,NORM2(U),NORM2(V))*EPS_DIFF) THEN
         DO K=3*J+1,3*NP
            PC(K-3) = PC(K)
         ENDDO
         NP = NP-1
         J = J-1
      ENDIF
      J = J+1
      IF (J > NP) EXIT
   ENDDO
   I = I+1
ENDDO

RETURN
END SUBROUTINE ELIMATE_REPEATED_POINTS

! ---------------------------- POINT_IN_BB ----------------------------------------

LOGICAL FUNCTION POINT_IN_BB(V1,BB)
IMPLICIT NONE

REAL(EB), INTENT(IN) :: V1(3),BB(6)

POINT_IN_BB=.FALSE.
IF ( V1(1)>=BB(1) .AND. V1(1)<=BB(2) .AND. &
     V1(2)>=BB(3) .AND. V1(2)<=BB(4) .AND. &
     V1(3)>=BB(5) .AND. V1(3)<=BB(6) ) THEN
   POINT_IN_BB=.TRUE.
   RETURN
ENDIF

RETURN
END FUNCTION POINT_IN_BB

! ---------------------------- LINE_SEG_TRI_PLANE_INTERSECT ----------------------------------------

SUBROUTINE LINE_SEG_TRI_PLANE_INTERSECT(IERR,IERR2,Q,V1,V2,V3,P0,P1)
USE MATH_FUNCTIONS, ONLY:CROSS_PRODUCT
IMPLICIT NONE

INTEGER, INTENT(OUT) :: IERR
REAL(EB), INTENT(OUT) :: Q(3)
REAL(EB), INTENT(IN) :: V1(3),V2(3),V3(3),P0(3),P1(3)
REAL(EB) :: E1(3),E2(3),S(3),U,V,TMP,T,D(3),P(3)
REAL(EB), PARAMETER :: EPS=1.E-10_EB,TOL=1.E-15
INTEGER :: IERR2

IERR  = 0
IERR2 = 1
! IERR=1:  line segment intersect with the plane
! IERR2=1: the intersection point is in the triangle

! Schneider and Eberly, Section 11.1

D = P1-P0
E1 = V2-V1
E2 = V3-V1

CALL CROSS_PRODUCT(P,D,E2)

TMP = DOT_PRODUCT(P,E1)

IF ( ABS(TMP)<EPS ) RETURN

TMP = 1._EB/TMP
S = P0-V1

U = TMP*DOT_PRODUCT(S,P)
IF (U<0._EB .OR. U>1._EB) IERR2=0

CALL CROSS_PRODUCT(Q,S,E1)
V = TMP*DOT_PRODUCT(D,Q)
IF (V<0._EB .OR. (U+V)>1._EB) IERR2=0

T = TMP*DOT_PRODUCT(E2,Q)
Q = P0 + T*D ! the intersection point

IF (T>=0._EB-TOL .AND. T<=1._EB+TOL) IERR=1

RETURN
END SUBROUTINE LINE_SEG_TRI_PLANE_INTERSECT

! ---------------------------- POLYGON_AREA ----------------------------------------

REAL(EB) FUNCTION POLYGON_AREA(NP,PC)
IMPLICIT NONE
! Calculate the area of a polygon

INTEGER, INTENT(IN) :: NP
REAL(EB), INTENT(IN) :: PC(60)
INTEGER :: I,K
REAL(EB) :: V1(3),V2(3),V3(3)
    
POLYGON_AREA = 0._EB
V3 = POLYGON_CENTROID(NP,PC)

DO I=1,NP
   IF (I < NP) THEN
      DO K=1,3
         V1(K) = PC((I-1)*3+K)
         V2(K) = PC(I*3+K)
      ENDDO
   ELSE
      DO K=1,3
         V1(K) = PC((I-1)*3+K)
         V2(K) = PC(K)
      ENDDO
   ENDIF
   POLYGON_AREA = POLYGON_AREA+TRIANGLE_AREA(V1,V2,V3)
ENDDO

RETURN
END FUNCTION POLYGON_AREA

! ---------------------------- POLYGON_CENTROID ----------------------------------------

REAL(EB) FUNCTION POLYGON_CENTROID(NP,PC)
IMPLICIT NONE
! Calculate the centroid of polygon vertices

DIMENSION :: POLYGON_CENTROID(3)
INTEGER, INTENT(IN) :: NP
REAL(EB), INTENT(IN) :: PC(60)
INTEGER :: I,K

POLYGON_CENTROID = 0._EB
DO I=1,NP
   DO K=1,3
      POLYGON_CENTROID(K) = POLYGON_CENTROID(K)+PC((I-1)*3+K)/NP
   ENDDO
ENDDO

RETURN
END FUNCTION POLYGON_CENTROID

! ---------------------------- TRIANGLE_ON_CELL_SURF ----------------------------------------

SUBROUTINE TRIANGLE_ON_CELL_SURF(IERR1,N_VEC,V,XC,YC,ZC,DX,DY,DZ)
USE MATH_FUNCTIONS, ONLY:NORM2
IMPLICIT NONE

INTEGER, INTENT(OUT) :: IERR1
REAL(EB), INTENT(IN) :: N_VEC(3),V(3),XC,YC,ZC,DX,DY,DZ
REAL(EB) :: DIST(3),TOL=1.E-15_EB

IERR1 = 1
DIST = 0._EB
!IF (NORM2(N_VEC)>1._EB) N_VEC = N_VEC/NORM2(N_VEC)

IF (N_VEC(1)==1._EB .OR. N_VEC(1)==-1._EB) THEN
   DIST(1) = XC-V(1)
   IF ( ABS(ABS(DIST(1))-DX*0.5_EB)<TOL .AND. DOT_PRODUCT(DIST,N_VEC)<0._EB) THEN
      IERR1 = -1
   ENDIF
   RETURN
ENDIF

IF (N_VEC(2)==1._EB .OR. N_VEC(2)==-1._EB) THEN
   DIST(2) = YC-V(2)
   IF ( ABS(ABS(DIST(2))-DY*0.5_EB)<TOL .AND. DOT_PRODUCT(DIST,N_VEC)<0._EB) THEN
      IERR1 = -1
   ENDIF
   RETURN
ENDIF

IF (N_VEC(3)==1._EB .OR. N_VEC(3)==-1._EB) THEN
   DIST(3) = ZC-V(3)
   IF ( ABS(ABS(DIST(3))-DZ*0.5_EB)<TOL .AND. DOT_PRODUCT(DIST,N_VEC)<0._EB) THEN
      IERR1 = -1
   ENDIF
   RETURN
ENDIF

RETURN
END SUBROUTINE TRIANGLE_ON_CELL_SURF

! ---------------------------- POLYGON_CLOSE_TO_EDGE ----------------------------------------

SUBROUTINE POLYGON_CLOSE_TO_EDGE(IOR,N_VEC,V,XC,YC,ZC,DX,DY,DZ)
IMPLICIT NONE
INTEGER, INTENT(OUT) :: IOR
REAL(EB), INTENT(IN) :: N_VEC(3),V(3),XC,YC,ZC,DX,DY,DZ
REAL(EB) :: DIST(3),DMAX
REAL(EB), PARAMETER :: TOLERANCE=0.01_EB

IOR = 0
DIST(1) = XC-V(1)
DIST(2) = YC-V(2)
DIST(3) = ZC-V(3)

IF (ABS(DIST(1)/DX) >= ABS(DIST(2)/DY) .AND. ABS(DIST(1)/DX) >= ABS(DIST(3)/DZ)) THEN
   DMAX = ABS(DIST(1)/DX*2._EB)
   IF (DMAX < (1._EB-TOLERANCE) .OR. DOT_PRODUCT(DIST,N_VEC) > 0._EB) RETURN
   IF (DIST(1) < 0._EB) THEN
      IOR = 1
   ELSE
      IOR = -1
   ENDIF
ELSEIF (ABS(DIST(2)/DY) >= ABS(DIST(3)/DZ)) THEN
   DMAX = ABS(DIST(2)/DY*2._EB)
   IF (DMAX < (1._EB-TOLERANCE) .OR. DOT_PRODUCT(DIST,N_VEC) > 0._EB) RETURN
   IF (DIST(2) < 0._EB) THEN
      IOR = 2
   ELSE
      IOR = -2
   ENDIF
ELSE
   DMAX = ABS(DIST(3)/DZ*2._EB)
   IF (DMAX < (1._EB-TOLERANCE) .OR. DOT_PRODUCT(DIST,N_VEC) > 0._EB) RETURN
   IF (DIST(3) < 0._EB) THEN
      IOR = 3
   ELSE
      IOR = -3
   ENDIF
ENDIF
   
END SUBROUTINE POLYGON_CLOSE_TO_EDGE

END MODULE COMPLEX_GEOMETRY
