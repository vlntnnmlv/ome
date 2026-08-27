package ome

// // import "base:intrinsics"
// // import "base:runtime"
// import cffi "core:c"

// when ODIN_OS == .Darwin {
// 	@(require) foreign import libslang "../../lib/libslang.dylib" // "./lib/libslang_debug.dylib",
// 	@(require) foreign import libcompiler "../../lib/libcompiler.dylib",

// 	// "lib/libslang.a",
// 	// "lib/libcore.a",
// 	// "lib/liblz4.a",
// 	// "lib/libminiz.a ",

// }


// ISession :: struct {}
// ICompileRequest :: struct {}
// IComponentType :: struct {}
// IModule :: struct {}
// IGlobalSession :: struct {}
// ISharedLibraryLoader :: struct {}
// IFileSystem :: struct {}
// IWriter :: struct {}
// CompileFlags :: struct {}
// IBlob :: struct {}
// ISharedLibrary :: struct {}
// IProfiler :: struct {}
// IMutableFileSystem :: struct {}
// IFileSystemExt :: struct {}
// TypeReflection :: struct {}


// DIAGNOSTIC_FLAG_VERBOSE_PATHS :: 1
// DIAGNOSTIC_FLAG_TREAT_WARNINGS_AS_ERRORS :: 2
// COMPILE_FLAG_NO_MANGLING :: 8
// COMPILE_FLAG_NO_CODEGEN :: 16
// COMPILE_FLAG_OBFUSCATE :: 32
// COMPILE_FLAG_NO_CHECKING :: 0
// COMPILE_FLAG_SPLIT_MIXED_TYPES :: 0
// TARGET_FLAG_PARAMETER_BLOCKS_USE_REGISTER_SPACES :: 16
// TARGET_FLAG_GENERATE_WHOLE_PROGRAM :: 256
// TARGET_FLAG_DUMP_IR :: 512
// TARGET_FLAG_GENERATE_SPIRV_DIRECTLY :: 1024
// @(default_calling_convention = "c")
// foreign libslang {
// 	@(require_results)
// 	@(link_name = "spReflection_GetSession")
// 	Reflection_GetSession :: proc(reflection: ^Reflection) -> ^ISession ---

// 	@(require_results)
// 	@(link_name = "spCreateSession")
// 	CreateSession :: proc(deprecated: cstring) -> ^Session ---

// 	@(link_name = "spDestroySession")
// 	DestroySession :: proc(session: ^Session) ---

// 	@(link_name = "spSessionSetSharedLibraryLoader")
// 	SessionSetSharedLibraryLoader :: proc(session: ^Session, loader: ^ISharedLibraryLoader) ---

// 	@(require_results)
// 	@(link_name = "spSessionGetSharedLibraryLoader")
// 	SessionGetSharedLibraryLoader :: proc(session: ^Session) -> ^ISharedLibraryLoader ---

// 	@(require_results)
// 	@(link_name = "spSessionCheckCompileTargetSupport")
// 	SessionCheckCompileTargetSupport :: proc(session: ^Session, target: CompileTarget) -> Result ---

// 	@(require_results)
// 	@(link_name = "spSessionCheckPassThroughSupport")
// 	SessionCheckPassThroughSupport :: proc(session: ^Session, passThrough: PassThrough) -> Result ---

// 	@(link_name = "spAddBuiltins")
// 	AddBuiltins :: proc(session: ^Session, sourcePath: cstring, sourceString: cstring) ---

// 	@(require_results)
// 	@(link_name = "spGetBuildTagString")
// 	GetBuildTagString :: proc() -> cstring ---

// 	@(require_results)
// 	@(link_name = "spCreateCompileRequest")
// 	CreateCompileRequest :: proc(session: ^Session) -> ^CompileRequest ---

// 	@(link_name = "spDestroyCompileRequest")
// 	DestroyCompileRequest :: proc(request: ^CompileRequest) ---

// 	@(link_name = "spSetFileSystem")
// 	SetFileSystem :: proc(request: ^CompileRequest, fileSystem: ^IFileSystem) ---

// 	@(link_name = "spSetCompileFlags")
// 	SetCompileFlags :: proc(request: ^CompileRequest, flags: CompileFlags) ---

// 	@(require_results)
// 	@(link_name = "spGetCompileFlags")
// 	GetCompileFlags :: proc(request: ^CompileRequest) -> CompileFlags ---

// 	@(link_name = "spSetDumpIntermediates")
// 	SetDumpIntermediates :: proc(request: ^CompileRequest, enable: cffi.int) ---

// 	@(link_name = "spSetDumpIntermediatePrefix")
// 	SetDumpIntermediatePrefix :: proc(request: ^CompileRequest, prefix: cstring) ---

// 	@(link_name = "spSetLineDirectiveMode")
// 	SetLineDirectiveMode :: proc(request: ^CompileRequest, mode: LineDirectiveMode) ---

// 	@(link_name = "spSetTargetLineDirectiveMode")
// 	SetTargetLineDirectiveMode :: proc(request: ^CompileRequest, targetIndex: cffi.int, mode: LineDirectiveMode) ---

// 	@(link_name = "spSetTargetForceGLSLScalarBufferLayout")
// 	SetTargetForceGLSLScalarBufferLayout :: proc(request: ^CompileRequest, targetIndex: cffi.int, forceScalarLayout: cffi.bool) ---

// 	@(link_name = "spSetTargetUseMinimumSlangOptimization")
// 	SetTargetUseMinimumSlangOptimization :: proc(request: ^ICompileRequest, targetIndex: cffi.int, val: cffi.bool) ---

// 	@(link_name = "spSetIgnoreCapabilityCheck")
// 	SetIgnoreCapabilityCheck :: proc(request: ^ICompileRequest, val: cffi.bool) ---

// 	@(link_name = "spSetCodeGenTarget")
// 	SetCodeGenTarget :: proc(request: ^CompileRequest, target: CompileTarget) ---

// 	@(require_results)
// 	@(link_name = "spAddCodeGenTarget")
// 	AddCodeGenTarget :: proc(request: ^CompileRequest, target: CompileTarget) -> cffi.int ---

// 	@(link_name = "spSetTargetProfile")
// 	SetTargetProfile :: proc(request: ^CompileRequest, targetIndex: cffi.int, profile: ProfileID) ---

// 	@(link_name = "spSetTargetFlags")
// 	SetTargetFlags :: proc(request: ^CompileRequest, targetIndex: cffi.int, flags: TargetFlags) ---

// 	@(link_name = "spSetTargetFloatingPointMode")
// 	SetTargetFloatingPointMode :: proc(request: ^CompileRequest, targetIndex: cffi.int, mode: FloatingPointMode) ---

// 	@(link_name = "spAddTargetCapability")
// 	AddTargetCapability :: proc(request: ^ICompileRequest, targetIndex: cffi.int, capability: CapabilityID) ---

// 	@(link_name = "spSetTargetMatrixLayoutMode")
// 	SetTargetMatrixLayoutMode :: proc(request: ^CompileRequest, targetIndex: cffi.int, mode: MatrixLayoutMode) ---

// 	@(link_name = "spSetMatrixLayoutMode")
// 	SetMatrixLayoutMode :: proc(request: ^CompileRequest, mode: MatrixLayoutMode) ---

// 	@(link_name = "spSetDebugInfoLevel")
// 	SetDebugInfoLevel :: proc(request: ^CompileRequest, level: DebugInfoLevel) ---

// 	@(link_name = "spSetDebugInfoFormat")
// 	SetDebugInfoFormat :: proc(request: ^CompileRequest, format: DebugInfoFormat) ---

// 	@(link_name = "spSetOptimizationLevel")
// 	SetOptimizationLevel :: proc(request: ^CompileRequest, level: OptimizationLevel) ---

// 	@(link_name = "spSetOutputContainerFormat")
// 	SetOutputContainerFormat :: proc(request: ^CompileRequest, format: ContainerFormat) ---

// 	@(link_name = "spSetPassThrough")
// 	SetPassThrough :: proc(request: ^CompileRequest, passThrough: PassThrough) ---

// 	@(link_name = "spSetDiagnosticCallback")
// 	SetDiagnosticCallback :: proc(request: ^CompileRequest, callback: DiagnosticCallback, userData: rawptr) ---

// 	@(link_name = "spSetWriter")
// 	SetWriter :: proc(request: ^CompileRequest, channel: WriterChannel, writer: ^IWriter) ---

// 	@(require_results)
// 	@(link_name = "spGetWriter")
// 	GetWriter :: proc(request: ^CompileRequest, channel: WriterChannel) -> ^IWriter ---

// 	@(link_name = "spAddSearchPath")
// 	AddSearchPath :: proc(request: ^CompileRequest, searchDir: cstring) ---

// 	@(link_name = "spAddPreprocessorDefine")
// 	AddPreprocessorDefine :: proc(request: ^CompileRequest, key: cstring, value: cstring) ---

// 	@(require_results)
// 	@(link_name = "spProcessCommandLineArguments")
// 	ProcessCommandLineArguments :: proc(request: ^CompileRequest, args: ^cstring, argCount: cffi.int) -> Result ---

// 	@(require_results)
// 	@(link_name = "spAddTranslationUnit")
// 	AddTranslationUnit :: proc(request: ^CompileRequest, language: SourceLanguage, name: cstring) -> cffi.int ---

// 	@(link_name = "spSetDefaultModuleName")
// 	SetDefaultModuleName :: proc(request: ^CompileRequest, defaultModuleName: cstring) ---

// 	@(link_name = "spTranslationUnit_addPreprocessorDefine")
// 	TranslationUnit_addPreprocessorDefine :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, key: cstring, value: cstring) ---

// 	@(link_name = "spAddTranslationUnitSourceFile")
// 	AddTranslationUnitSourceFile :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, path: cstring) ---

// 	@(link_name = "spAddTranslationUnitSourceString")
// 	AddTranslationUnitSourceString :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, path: cstring, source: cstring) ---

// 	@(require_results)
// 	@(link_name = "spAddLibraryReference")
// 	AddLibraryReference :: proc(request: ^CompileRequest, basePath: cstring, libData: rawptr, libDataSize: cffi.size_t) -> Result ---

// 	@(link_name = "spAddTranslationUnitSourceStringSpan")
// 	AddTranslationUnitSourceStringSpan :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, path: cstring, sourceBegin: cstring, sourceEnd: cstring) ---

// 	@(link_name = "spAddTranslationUnitSourceBlob")
// 	AddTranslationUnitSourceBlob :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, path: cstring, sourceBlob: ^IBlob) ---

// 	@(require_results)
// 	@(link_name = "spFindProfile")
// 	FindProfile :: proc(session: ^Session, name: cstring) -> ProfileID ---

// 	@(require_results)
// 	@(link_name = "spFindCapability")
// 	FindCapability :: proc(session: ^Session, name: cstring) -> CapabilityID ---

// 	@(require_results)
// 	@(link_name = "spAddEntryPoint")
// 	AddEntryPoint :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, name: cstring, stage: Stage) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spAddEntryPointEx")
// 	AddEntryPointEx :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int, name: cstring, stage: Stage, genericArgCount: cffi.int, genericArgs: ^cstring) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spSetGlobalGenericArgs")
// 	SetGlobalGenericArgs :: proc(request: ^CompileRequest, genericArgCount: cffi.int, genericArgs: ^cstring) -> Result ---

// 	@(require_results)
// 	@(link_name = "spSetTypeNameForGlobalExistentialTypeParam")
// 	SetTypeNameForGlobalExistentialTypeParam :: proc(request: ^CompileRequest, slotIndex: cffi.int, typeName: cstring) -> Result ---

// 	@(require_results)
// 	@(link_name = "spSetTypeNameForEntryPointExistentialTypeParam")
// 	SetTypeNameForEntryPointExistentialTypeParam :: proc(request: ^CompileRequest, entryPointIndex: cffi.int, slotIndex: cffi.int, typeName: cstring) -> Result ---

// 	@(require_results)
// 	@(link_name = "spCompile")
// 	Compile :: proc(request: ^CompileRequest) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetDiagnosticOutput")
// 	GetDiagnosticOutput :: proc(request: ^CompileRequest) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spGetDiagnosticOutputBlob")
// 	GetDiagnosticOutputBlob :: proc(request: ^CompileRequest, outBlob: ^^IBlob) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetDependencyFileCount")
// 	GetDependencyFileCount :: proc(request: ^CompileRequest) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spGetDependencyFilePath")
// 	GetDependencyFilePath :: proc(request: ^CompileRequest, index: cffi.int) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spGetTranslationUnitCount")
// 	GetTranslationUnitCount :: proc(request: ^CompileRequest) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spGetEntryPointSource")
// 	GetEntryPointSource :: proc(request: ^CompileRequest, entryPointIndex: cffi.int) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spGetEntryPointCode")
// 	GetEntryPointCode :: proc(request: ^CompileRequest, entryPointIndex: cffi.int, outSize: ^cffi.size_t) -> rawptr ---

// 	@(require_results)
// 	@(link_name = "spGetEntryPointCodeBlob")
// 	GetEntryPointCodeBlob :: proc(request: ^CompileRequest, entryPointIndex: cffi.int, targetIndex: cffi.int, outBlob: ^^IBlob) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetEntryPointHostCallable")
// 	GetEntryPointHostCallable :: proc(request: ^CompileRequest, entryPointIndex: cffi.int, targetIndex: cffi.int, outSharedLibrary: ^^ISharedLibrary) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetTargetCodeBlob")
// 	GetTargetCodeBlob :: proc(request: ^CompileRequest, targetIndex: cffi.int, outBlob: ^^IBlob) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetTargetHostCallable")
// 	GetTargetHostCallable :: proc(request: ^CompileRequest, targetIndex: cffi.int, outSharedLibrary: ^^ISharedLibrary) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetCompileRequestCode")
// 	GetCompileRequestCode :: proc(request: ^CompileRequest, outSize: ^cffi.size_t) -> rawptr ---

// 	@(require_results)
// 	@(link_name = "spGetContainerCode")
// 	GetContainerCode :: proc(request: ^CompileRequest, outBlob: ^^IBlob) -> Result ---

// 	@(require_results)
// 	@(link_name = "spLoadRepro")
// 	LoadRepro :: proc(request: ^CompileRequest, fileSystem: ^IFileSystem, data: rawptr, size: cffi.size_t) -> Result ---

// 	@(require_results)
// 	@(link_name = "spSaveRepro")
// 	SaveRepro :: proc(request: ^CompileRequest, outBlob: ^^IBlob) -> Result ---

// 	@(require_results)
// 	@(link_name = "spEnableReproCapture")
// 	EnableReproCapture :: proc(request: ^CompileRequest) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetCompileTimeProfile")
// 	GetCompileTimeProfile :: proc(request: ^CompileRequest, compileTimeProfile: ^^IProfiler, shouldClear: cffi.bool) -> Result ---

// 	@(require_results)
// 	@(link_name = "spExtractRepro")
// 	ExtractRepro :: proc(session: ^Session, reproData: rawptr, reproDataSize: cffi.size_t, fileSystem: ^IMutableFileSystem) -> Result ---

// 	@(require_results)
// 	@(link_name = "spLoadReproAsFileSystem")
// 	LoadReproAsFileSystem :: proc(session: ^Session, reproData: rawptr, reproDataSize: cffi.size_t, replaceFileSystem: ^IFileSystem, outFileSystem: ^^IFileSystemExt) -> Result ---

// 	@(link_name = "spOverrideDiagnosticSeverity")
// 	OverrideDiagnosticSeverity :: proc(request: ^CompileRequest, messageID: Int, overrideSeverity: Severity) ---

// 	@(require_results)
// 	@(link_name = "spGetDiagnosticFlags")
// 	GetDiagnosticFlags :: proc(request: ^CompileRequest) -> DiagnosticFlags ---

// 	@(link_name = "spSetDiagnosticFlags")
// 	SetDiagnosticFlags :: proc(request: ^CompileRequest, flags: DiagnosticFlags) ---

// 	@(require_results)
// 	@(link_name = "spGetReflection")
// 	GetReflection :: proc(request: ^CompileRequest) -> ^Reflection ---

// 	@(require_results)
// 	@(link_name = "spReflectionUserAttribute_GetName")
// 	ReflectionUserAttribute_GetName :: proc(attrib: ^ReflectionUserAttribute) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionUserAttribute_GetArgumentCount")
// 	ReflectionUserAttribute_GetArgumentCount :: proc(attrib: ^ReflectionUserAttribute) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionUserAttribute_GetArgumentType")
// 	ReflectionUserAttribute_GetArgumentType :: proc(attrib: ^ReflectionUserAttribute, index: cffi.uint) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionUserAttribute_GetArgumentValueInt")
// 	ReflectionUserAttribute_GetArgumentValueInt :: proc(attrib: ^ReflectionUserAttribute, index: cffi.uint, rs: ^cffi.int) -> Result ---

// 	@(require_results)
// 	@(link_name = "spReflectionUserAttribute_GetArgumentValueFloat")
// 	ReflectionUserAttribute_GetArgumentValueFloat :: proc(attrib: ^ReflectionUserAttribute, index: cffi.uint, rs: ^cffi.float) -> Result ---

// 	@(require_results)
// 	@(link_name = "spReflectionUserAttribute_GetArgumentValueString")
// 	ReflectionUserAttribute_GetArgumentValueString :: proc(attrib: ^ReflectionUserAttribute, index: cffi.uint, outSize: ^cffi.size_t) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetKind")
// 	ReflectionType_GetKind :: proc(type: ^ReflectionType) -> TypeKind ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetUserAttributeCount")
// 	ReflectionType_GetUserAttributeCount :: proc(type: ^ReflectionType) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetUserAttribute")
// 	ReflectionType_GetUserAttribute :: proc(type: ^ReflectionType, index: cffi.uint) -> ^ReflectionUserAttribute ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_FindUserAttributeByName")
// 	ReflectionType_FindUserAttributeByName :: proc(type: ^ReflectionType, name: cstring) -> ^ReflectionUserAttribute ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_applySpecializations")
// 	ReflectionType_applySpecializations :: proc(type: ^ReflectionType, generic: ^ReflectionGeneric) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetFieldCount")
// 	ReflectionType_GetFieldCount :: proc(type: ^ReflectionType) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetFieldByIndex")
// 	ReflectionType_GetFieldByIndex :: proc(type: ^ReflectionType, index: cffi.uint) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetElementCount")
// 	ReflectionType_GetElementCount :: proc(type: ^ReflectionType) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetElementType")
// 	ReflectionType_GetElementType :: proc(type: ^ReflectionType) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetRowCount")
// 	ReflectionType_GetRowCount :: proc(type: ^ReflectionType) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetColumnCount")
// 	ReflectionType_GetColumnCount :: proc(type: ^ReflectionType) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetScalarType")
// 	ReflectionType_GetScalarType :: proc(type: ^ReflectionType) -> ScalarType ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetResourceShape")
// 	ReflectionType_GetResourceShape :: proc(type: ^ReflectionType) -> ResourceShape ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetResourceAccess")
// 	ReflectionType_GetResourceAccess :: proc(type: ^ReflectionType) -> ResourceAccess ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetResourceResultType")
// 	ReflectionType_GetResourceResultType :: proc(type: ^ReflectionType) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetName")
// 	ReflectionType_GetName :: proc(type: ^ReflectionType) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetFullName")
// 	ReflectionType_GetFullName :: proc(type: ^ReflectionType, outNameBlob: ^^IBlob) -> Result ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_GetGenericContainer")
// 	ReflectionType_GetGenericContainer :: proc(type: ^ReflectionType) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetType")
// 	ReflectionTypeLayout_GetType :: proc(type: ^ReflectionTypeLayout) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getKind")
// 	ReflectionTypeLayout_getKind :: proc(type: ^ReflectionTypeLayout) -> TypeKind ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetSize")
// 	ReflectionTypeLayout_GetSize :: proc(type: ^ReflectionTypeLayout, category: ParameterCategory) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetStride")
// 	ReflectionTypeLayout_GetStride :: proc(type: ^ReflectionTypeLayout, category: ParameterCategory) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getAlignment")
// 	ReflectionTypeLayout_getAlignment :: proc(type: ^ReflectionTypeLayout, category: ParameterCategory) -> cffi.int32_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetFieldCount")
// 	ReflectionTypeLayout_GetFieldCount :: proc(type: ^ReflectionTypeLayout) -> cffi.uint32_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetFieldByIndex")
// 	ReflectionTypeLayout_GetFieldByIndex :: proc(type: ^ReflectionTypeLayout, index: cffi.uint) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_findFieldIndexByName")
// 	ReflectionTypeLayout_findFieldIndexByName :: proc(typeLayout: ^ReflectionTypeLayout, nameBegin: cstring, nameEnd: cstring) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetExplicitCounter")
// 	ReflectionTypeLayout_GetExplicitCounter :: proc(typeLayout: ^ReflectionTypeLayout) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetElementStride")
// 	ReflectionTypeLayout_GetElementStride :: proc(type: ^ReflectionTypeLayout, category: ParameterCategory) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetElementTypeLayout")
// 	ReflectionTypeLayout_GetElementTypeLayout :: proc(type: ^ReflectionTypeLayout) -> ^ReflectionTypeLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetElementVarLayout")
// 	ReflectionTypeLayout_GetElementVarLayout :: proc(type: ^ReflectionTypeLayout) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getContainerVarLayout")
// 	ReflectionTypeLayout_getContainerVarLayout :: proc(type: ^ReflectionTypeLayout) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetParameterCategory")
// 	ReflectionTypeLayout_GetParameterCategory :: proc(type: ^ReflectionTypeLayout) -> ParameterCategory ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetCategoryCount")
// 	ReflectionTypeLayout_GetCategoryCount :: proc(type: ^ReflectionTypeLayout) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetCategoryByIndex")
// 	ReflectionTypeLayout_GetCategoryByIndex :: proc(type: ^ReflectionTypeLayout, index: cffi.uint) -> ParameterCategory ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_GetMatrixLayoutMode")
// 	ReflectionTypeLayout_GetMatrixLayoutMode :: proc(type: ^ReflectionTypeLayout) -> MatrixLayoutMode ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getGenericParamIndex")
// 	ReflectionTypeLayout_getGenericParamIndex :: proc(type: ^ReflectionTypeLayout) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getPendingDataTypeLayout")
// 	ReflectionTypeLayout_getPendingDataTypeLayout :: proc(type: ^ReflectionTypeLayout) -> ^ReflectionTypeLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getSpecializedTypePendingDataVarLayout")
// 	ReflectionTypeLayout_getSpecializedTypePendingDataVarLayout :: proc(type: ^ReflectionTypeLayout) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_getSpecializedTypeArgCount")
// 	ReflectionType_getSpecializedTypeArgCount :: proc(type: ^ReflectionType) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionType_getSpecializedTypeArgType")
// 	ReflectionType_getSpecializedTypeArgType :: proc(type: ^ReflectionType, index: Int) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeCount")
// 	ReflectionTypeLayout_getBindingRangeCount :: proc(typeLayout: ^ReflectionTypeLayout) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeType")
// 	ReflectionTypeLayout_getBindingRangeType :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> BindingType ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_isBindingRangeSpecializable")
// 	ReflectionTypeLayout_isBindingRangeSpecializable :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeBindingCount")
// 	ReflectionTypeLayout_getBindingRangeBindingCount :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeLeafTypeLayout")
// 	ReflectionTypeLayout_getBindingRangeLeafTypeLayout :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> ^ReflectionTypeLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeLeafVariable")
// 	ReflectionTypeLayout_getBindingRangeLeafVariable :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeImageFormat")
// 	ReflectionTypeLayout_getBindingRangeImageFormat :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> ImageFormat ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getFieldBindingRangeOffset")
// 	ReflectionTypeLayout_getFieldBindingRangeOffset :: proc(typeLayout: ^ReflectionTypeLayout, fieldIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getExplicitCounterBindingRangeOffset")
// 	ReflectionTypeLayout_getExplicitCounterBindingRangeOffset :: proc(inTypeLayout: ^ReflectionTypeLayout) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeDescriptorSetIndex")
// 	ReflectionTypeLayout_getBindingRangeDescriptorSetIndex :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeFirstDescriptorRangeIndex")
// 	ReflectionTypeLayout_getBindingRangeFirstDescriptorRangeIndex :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getBindingRangeDescriptorRangeCount")
// 	ReflectionTypeLayout_getBindingRangeDescriptorRangeCount :: proc(typeLayout: ^ReflectionTypeLayout, index: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetCount")
// 	ReflectionTypeLayout_getDescriptorSetCount :: proc(typeLayout: ^ReflectionTypeLayout) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetSpaceOffset")
// 	ReflectionTypeLayout_getDescriptorSetSpaceOffset :: proc(typeLayout: ^ReflectionTypeLayout, setIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetDescriptorRangeCount")
// 	ReflectionTypeLayout_getDescriptorSetDescriptorRangeCount :: proc(typeLayout: ^ReflectionTypeLayout, setIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetDescriptorRangeIndexOffset")
// 	ReflectionTypeLayout_getDescriptorSetDescriptorRangeIndexOffset :: proc(typeLayout: ^ReflectionTypeLayout, setIndex: Int, rangeIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetDescriptorRangeDescriptorCount")
// 	ReflectionTypeLayout_getDescriptorSetDescriptorRangeDescriptorCount :: proc(typeLayout: ^ReflectionTypeLayout, setIndex: Int, rangeIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetDescriptorRangeType")
// 	ReflectionTypeLayout_getDescriptorSetDescriptorRangeType :: proc(typeLayout: ^ReflectionTypeLayout, setIndex: Int, rangeIndex: Int) -> BindingType ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getDescriptorSetDescriptorRangeCategory")
// 	ReflectionTypeLayout_getDescriptorSetDescriptorRangeCategory :: proc(typeLayout: ^ReflectionTypeLayout, setIndex: Int, rangeIndex: Int) -> ParameterCategory ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getSubObjectRangeCount")
// 	ReflectionTypeLayout_getSubObjectRangeCount :: proc(typeLayout: ^ReflectionTypeLayout) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getSubObjectRangeBindingRangeIndex")
// 	ReflectionTypeLayout_getSubObjectRangeBindingRangeIndex :: proc(typeLayout: ^ReflectionTypeLayout, subObjectRangeIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getSubObjectRangeSpaceOffset")
// 	ReflectionTypeLayout_getSubObjectRangeSpaceOffset :: proc(typeLayout: ^ReflectionTypeLayout, subObjectRangeIndex: Int) -> Int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeLayout_getSubObjectRangeOffset")
// 	ReflectionTypeLayout_getSubObjectRangeOffset :: proc(typeLayout: ^ReflectionTypeLayout, subObjectRangeIndex: Int) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_GetName")
// 	ReflectionVariable_GetName :: proc(var: ^ReflectionVariable) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_GetType")
// 	ReflectionVariable_GetType :: proc(var: ^ReflectionVariable) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_FindModifier")
// 	ReflectionVariable_FindModifier :: proc(var: ^ReflectionVariable, modifierID: ModifierID) -> ^ReflectionModifier ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_GetUserAttributeCount")
// 	ReflectionVariable_GetUserAttributeCount :: proc(var: ^ReflectionVariable) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_GetUserAttribute")
// 	ReflectionVariable_GetUserAttribute :: proc(var: ^ReflectionVariable, index: cffi.uint) -> ^ReflectionUserAttribute ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_FindUserAttributeByName")
// 	ReflectionVariable_FindUserAttributeByName :: proc(var: ^ReflectionVariable, globalSession: ^Session, name: cstring) -> ^ReflectionUserAttribute ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_HasDefaultValue")
// 	ReflectionVariable_HasDefaultValue :: proc(inVar: ^ReflectionVariable) -> cffi.bool ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_GetGenericContainer")
// 	ReflectionVariable_GetGenericContainer :: proc(var: ^ReflectionVariable) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariable_applySpecializations")
// 	ReflectionVariable_applySpecializations :: proc(var: ^ReflectionVariable, generic: ^ReflectionGeneric) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_GetVariable")
// 	ReflectionVariableLayout_GetVariable :: proc(var: ^ReflectionVariableLayout) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_GetTypeLayout")
// 	ReflectionVariableLayout_GetTypeLayout :: proc(var: ^ReflectionVariableLayout) -> ^ReflectionTypeLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_GetOffset")
// 	ReflectionVariableLayout_GetOffset :: proc(var: ^ReflectionVariableLayout, category: ParameterCategory) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_GetSpace")
// 	ReflectionVariableLayout_GetSpace :: proc(var: ^ReflectionVariableLayout, category: ParameterCategory) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_GetSemanticName")
// 	ReflectionVariableLayout_GetSemanticName :: proc(var: ^ReflectionVariableLayout) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_GetSemanticIndex")
// 	ReflectionVariableLayout_GetSemanticIndex :: proc(var: ^ReflectionVariableLayout) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_asDecl")
// 	ReflectionFunction_asDecl :: proc(func: ^ReflectionFunction) -> ^ReflectionDecl ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetName")
// 	ReflectionFunction_GetName :: proc(func: ^ReflectionFunction) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_FindModifier")
// 	ReflectionFunction_FindModifier :: proc(var: ^ReflectionFunction, modifierID: ModifierID) -> ^ReflectionModifier ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetUserAttributeCount")
// 	ReflectionFunction_GetUserAttributeCount :: proc(func: ^ReflectionFunction) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetUserAttribute")
// 	ReflectionFunction_GetUserAttribute :: proc(func: ^ReflectionFunction, index: cffi.uint) -> ^ReflectionUserAttribute ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_FindUserAttributeByName")
// 	ReflectionFunction_FindUserAttributeByName :: proc(func: ^ReflectionFunction, globalSession: ^Session, name: cstring) -> ^ReflectionUserAttribute ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetParameterCount")
// 	ReflectionFunction_GetParameterCount :: proc(func: ^ReflectionFunction) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetParameter")
// 	ReflectionFunction_GetParameter :: proc(func: ^ReflectionFunction, index: cffi.uint) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetResultType")
// 	ReflectionFunction_GetResultType :: proc(func: ^ReflectionFunction) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_GetGenericContainer")
// 	ReflectionFunction_GetGenericContainer :: proc(func: ^ReflectionFunction) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_applySpecializations")
// 	ReflectionFunction_applySpecializations :: proc(func: ^ReflectionFunction, generic: ^ReflectionGeneric) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_specializeWithArgTypes")
// 	ReflectionFunction_specializeWithArgTypes :: proc(func: ^ReflectionFunction, argTypeCount: Int, argTypes: ^^ReflectionType) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_isOverloaded")
// 	ReflectionFunction_isOverloaded :: proc(func: ^ReflectionFunction) -> cffi.bool ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_getOverloadCount")
// 	ReflectionFunction_getOverloadCount :: proc(func: ^ReflectionFunction) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionFunction_getOverload")
// 	ReflectionFunction_getOverload :: proc(func: ^ReflectionFunction, index: cffi.uint) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_getChildrenCount")
// 	ReflectionDecl_getChildrenCount :: proc(parentDecl: ^ReflectionDecl) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_getChild")
// 	ReflectionDecl_getChild :: proc(parentDecl: ^ReflectionDecl, index: cffi.uint) -> ^ReflectionDecl ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_getName")
// 	ReflectionDecl_getName :: proc(decl: ^ReflectionDecl) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_getKind")
// 	ReflectionDecl_getKind :: proc(decl: ^ReflectionDecl) -> DeclKind ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_castToFunction")
// 	ReflectionDecl_castToFunction :: proc(decl: ^ReflectionDecl) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_castToVariable")
// 	ReflectionDecl_castToVariable :: proc(decl: ^ReflectionDecl) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_castToGeneric")
// 	ReflectionDecl_castToGeneric :: proc(decl: ^ReflectionDecl) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflection_getTypeFromDecl")
// 	Reflection_getTypeFromDecl :: proc(decl: ^ReflectionDecl) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionDecl_getParent")
// 	ReflectionDecl_getParent :: proc(decl: ^ReflectionDecl) -> ^ReflectionDecl ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_asDecl")
// 	ReflectionGeneric_asDecl :: proc(generic: ^ReflectionGeneric) -> ^ReflectionDecl ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetName")
// 	ReflectionGeneric_GetName :: proc(generic: ^ReflectionGeneric) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetTypeParameterCount")
// 	ReflectionGeneric_GetTypeParameterCount :: proc(generic: ^ReflectionGeneric) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetTypeParameter")
// 	ReflectionGeneric_GetTypeParameter :: proc(generic: ^ReflectionGeneric, index: cffi.uint) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetValueParameterCount")
// 	ReflectionGeneric_GetValueParameterCount :: proc(generic: ^ReflectionGeneric) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetValueParameter")
// 	ReflectionGeneric_GetValueParameter :: proc(generic: ^ReflectionGeneric, index: cffi.uint) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetTypeParameterConstraintCount")
// 	ReflectionGeneric_GetTypeParameterConstraintCount :: proc(generic: ^ReflectionGeneric, typeParam: ^ReflectionVariable) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetTypeParameterConstraintType")
// 	ReflectionGeneric_GetTypeParameterConstraintType :: proc(generic: ^ReflectionGeneric, typeParam: ^ReflectionVariable, index: cffi.uint) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetInnerKind")
// 	ReflectionGeneric_GetInnerKind :: proc(generic: ^ReflectionGeneric) -> DeclKind ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetInnerDecl")
// 	ReflectionGeneric_GetInnerDecl :: proc(generic: ^ReflectionGeneric) -> ^ReflectionDecl ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetOuterGenericContainer")
// 	ReflectionGeneric_GetOuterGenericContainer :: proc(generic: ^ReflectionGeneric) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetConcreteType")
// 	ReflectionGeneric_GetConcreteType :: proc(generic: ^ReflectionGeneric, typeParam: ^ReflectionVariable) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_GetConcreteIntVal")
// 	ReflectionGeneric_GetConcreteIntVal :: proc(generic: ^ReflectionGeneric, valueParam: ^ReflectionVariable) -> cffi.int64_t ---

// 	@(require_results)
// 	@(link_name = "spReflectionGeneric_applySpecializations")
// 	ReflectionGeneric_applySpecializations :: proc(currGeneric: ^ReflectionGeneric, generic: ^ReflectionGeneric) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_getStage")
// 	ReflectionVariableLayout_getStage :: proc(var: ^ReflectionVariableLayout) -> Stage ---

// 	@(require_results)
// 	@(link_name = "spReflectionVariableLayout_getPendingDataLayout")
// 	ReflectionVariableLayout_getPendingDataLayout :: proc(var: ^ReflectionVariableLayout) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionParameter_GetBindingIndex")
// 	ReflectionParameter_GetBindingIndex :: proc(parameter: ^ReflectionParameter) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionParameter_GetBindingSpace")
// 	ReflectionParameter_GetBindingSpace :: proc(parameter: ^ReflectionParameter) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spIsParameterLocationUsed")
// 	IsParameterLocationUsed :: proc(request: ^CompileRequest, entryPointIndex: Int, targetIndex: Int, category: ParameterCategory, spaceIndex: UInt, registerIndex: UInt, outUsed: ^cffi.bool) -> Result ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getName")
// 	ReflectionEntryPoint_getName :: proc(entryPoint: ^ReflectionEntryPoint) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getNameOverride")
// 	ReflectionEntryPoint_getNameOverride :: proc(entryPoint: ^ReflectionEntryPoint) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getFunction")
// 	ReflectionEntryPoint_getFunction :: proc(entryPoint: ^ReflectionEntryPoint) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getParameterCount")
// 	ReflectionEntryPoint_getParameterCount :: proc(entryPoint: ^ReflectionEntryPoint) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getParameterByIndex")
// 	ReflectionEntryPoint_getParameterByIndex :: proc(entryPoint: ^ReflectionEntryPoint, index: cffi.uint) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getStage")
// 	ReflectionEntryPoint_getStage :: proc(entryPoint: ^ReflectionEntryPoint) -> Stage ---

// 	@(link_name = "spReflectionEntryPoint_getComputeThreadGroupSize")
// 	ReflectionEntryPoint_getComputeThreadGroupSize :: proc(entryPoint: ^ReflectionEntryPoint, axisCount: UInt, outSizeAlongAxis: ^UInt) ---

// 	@(link_name = "spReflectionEntryPoint_getComputeWaveSize")
// 	ReflectionEntryPoint_getComputeWaveSize :: proc(entryPoint: ^ReflectionEntryPoint, outWaveSize: ^UInt) ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_usesAnySampleRateInput")
// 	ReflectionEntryPoint_usesAnySampleRateInput :: proc(entryPoint: ^ReflectionEntryPoint) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getVarLayout")
// 	ReflectionEntryPoint_getVarLayout :: proc(entryPoint: ^ReflectionEntryPoint) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_getResultVarLayout")
// 	ReflectionEntryPoint_getResultVarLayout :: proc(entryPoint: ^ReflectionEntryPoint) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "spReflectionEntryPoint_hasDefaultConstantBuffer")
// 	ReflectionEntryPoint_hasDefaultConstantBuffer :: proc(entryPoint: ^ReflectionEntryPoint) -> cffi.int ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeParameter_GetName")
// 	ReflectionTypeParameter_GetName :: proc(typeParam: ^ReflectionTypeParameter) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeParameter_GetIndex")
// 	ReflectionTypeParameter_GetIndex :: proc(typeParam: ^ReflectionTypeParameter) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeParameter_GetConstraintCount")
// 	ReflectionTypeParameter_GetConstraintCount :: proc(typeParam: ^ReflectionTypeParameter) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflectionTypeParameter_GetConstraintByIndex")
// 	ReflectionTypeParameter_GetConstraintByIndex :: proc(typeParam: ^ReflectionTypeParameter, index: cffi.uint) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflection_GetParameterCount")
// 	Reflection_GetParameterCount :: proc(reflection: ^Reflection) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflection_GetParameterByIndex")
// 	Reflection_GetParameterByIndex :: proc(reflection: ^Reflection, index: cffi.uint) -> ^ReflectionParameter ---

// 	@(require_results)
// 	@(link_name = "spReflection_GetTypeParameterCount")
// 	Reflection_GetTypeParameterCount :: proc(reflection: ^Reflection) -> cffi.uint ---

// 	@(require_results)
// 	@(link_name = "spReflection_GetTypeParameterByIndex")
// 	Reflection_GetTypeParameterByIndex :: proc(reflection: ^Reflection, index: cffi.uint) -> ^ReflectionTypeParameter ---

// 	@(require_results)
// 	@(link_name = "spReflection_FindTypeParameter")
// 	Reflection_FindTypeParameter :: proc(reflection: ^Reflection, name: cstring) -> ^ReflectionTypeParameter ---

// 	@(require_results)
// 	@(link_name = "spReflection_FindTypeByName")
// 	Reflection_FindTypeByName :: proc(reflection: ^Reflection, name: cstring) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflection_GetTypeLayout")
// 	Reflection_GetTypeLayout :: proc(reflection: ^Reflection, reflectionType: ^ReflectionType, rules: LayoutRules) -> ^ReflectionTypeLayout ---

// 	@(require_results)
// 	@(link_name = "spReflection_FindFunctionByName")
// 	Reflection_FindFunctionByName :: proc(reflection: ^Reflection, name: cstring) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflection_FindFunctionByNameInType")
// 	Reflection_FindFunctionByNameInType :: proc(reflection: ^Reflection, reflType: ^ReflectionType, name: cstring) -> ^ReflectionFunction ---

// 	@(require_results)
// 	@(link_name = "spReflection_FindVarByNameInType")
// 	Reflection_FindVarByNameInType :: proc(reflection: ^Reflection, reflType: ^ReflectionType, name: cstring) -> ^ReflectionVariable ---

// 	@(require_results)
// 	@(link_name = "spReflection_getEntryPointCount")
// 	Reflection_getEntryPointCount :: proc(reflection: ^Reflection) -> UInt ---

// 	@(require_results)
// 	@(link_name = "spReflection_getEntryPointByIndex")
// 	Reflection_getEntryPointByIndex :: proc(reflection: ^Reflection, index: UInt) -> ^ReflectionEntryPoint ---

// 	@(require_results)
// 	@(link_name = "spReflection_findEntryPointByName")
// 	Reflection_findEntryPointByName :: proc(reflection: ^Reflection, name: cstring) -> ^ReflectionEntryPoint ---

// 	@(require_results)
// 	@(link_name = "spReflection_getGlobalConstantBufferBinding")
// 	Reflection_getGlobalConstantBufferBinding :: proc(reflection: ^Reflection) -> UInt ---

// 	@(require_results)
// 	@(link_name = "spReflection_getGlobalConstantBufferSize")
// 	Reflection_getGlobalConstantBufferSize :: proc(reflection: ^Reflection) -> cffi.size_t ---

// 	@(require_results)
// 	@(link_name = "spReflection_specializeType")
// 	Reflection_specializeType :: proc(reflection: ^Reflection, type: ^ReflectionType, specializationArgCount: Int, specializationArgs: ^^ReflectionType, outDiagnostics: ^^IBlob) -> ^ReflectionType ---

// 	@(require_results)
// 	@(link_name = "spReflection_specializeGeneric")
// 	Reflection_specializeGeneric :: proc(inProgramLayout: ^Reflection, generic: ^ReflectionGeneric, argCount: Int, argTypes: ^ReflectionGenericArgType, args: ^ReflectionGenericArg, outDiagnostics: ^^IBlob) -> ^ReflectionGeneric ---

// 	@(require_results)
// 	@(link_name = "spReflection_isSubType")
// 	Reflection_isSubType :: proc(reflection: ^Reflection, subType: ^ReflectionType, superType: ^ReflectionType) -> cffi.bool ---

// 	@(require_results)
// 	@(link_name = "spReflection_getHashedStringCount")
// 	Reflection_getHashedStringCount :: proc(reflection: ^Reflection) -> UInt ---

// 	@(require_results)
// 	@(link_name = "spReflection_getHashedString")
// 	Reflection_getHashedString :: proc(reflection: ^Reflection, index: UInt, outCount: ^cffi.size_t) -> cstring ---

// 	@(require_results)
// 	@(link_name = "spComputeStringHash")
// 	ComputeStringHash :: proc(chars: cstring, count: cffi.size_t) -> UInt32 ---

// 	@(require_results)
// 	@(link_name = "spReflection_getGlobalParamsTypeLayout")
// 	Reflection_getGlobalParamsTypeLayout :: proc(reflection: ^Reflection) -> ^ReflectionTypeLayout ---

// 	@(require_results)
// 	@(link_name = "spReflection_getGlobalParamsVarLayout")
// 	Reflection_getGlobalParamsVarLayout :: proc(reflection: ^Reflection) -> ^ReflectionVariableLayout ---

// 	@(require_results)
// 	@(link_name = "slang_createGlobalSession")
// 	slang_createGlobalSession :: proc(apiVersion: Int, outGlobalSession: ^^IGlobalSession) -> Result ---

// 	@(require_results)
// 	@(link_name = "slang_createGlobalSessionWithoutStdLib")
// 	slang_createGlobalSessionWithoutStdLib :: proc(apiVersion: Int, outGlobalSession: ^^IGlobalSession) -> Result ---

// 	@(require_results)
// 	@(link_name = "spCompileRequest_getProgram")
// 	CompileRequest_getProgram :: proc(request: ^CompileRequest, outProgram: ^^IComponentType) -> Result ---

// 	@(require_results)
// 	@(link_name = "spCompileRequest_getProgramWithEntryPoints")
// 	CompileRequest_getProgramWithEntryPoints :: proc(request: ^CompileRequest, outProgram: ^^IComponentType) -> Result ---

// 	@(require_results)
// 	@(link_name = "spCompileRequest_getEntryPoint")
// 	CompileRequest_getEntryPoint :: proc(request: ^CompileRequest, entryPointIndex: Int, outEntryPoint: ^^IComponentType) -> Result ---

// 	@(require_results)
// 	@(link_name = "spCompileRequest_getModule")
// 	CompileRequest_getModule :: proc(request: ^CompileRequest, translationUnitIndex: Int, outModule: ^^IModule) -> Result ---

// 	@(require_results)
// 	@(link_name = "spCompileRequest_getSession")
// 	CompileRequest_getSession :: proc(request: ^CompileRequest, outSession: ^^ISession) -> Result ---

// 	@(require_results)
// 	@(link_name = "spGetTranslationUnitSource")
// 	GetTranslationUnitSource :: proc(request: ^CompileRequest, translationUnitIndex: cffi.int) -> cstring ---

// }

// /// SlangUInt32
// UInt32 :: distinct cffi.uint32_t

// /// SlangInt32
// Int32 :: distinct cffi.int32_t

// /// SlangInt
// Int :: distinct cffi.int64_t

// /// SlangUInt
// UInt :: distinct cffi.uint64_t

// /// SlangSSizeT
// SSizeT :: distinct cffi.int64_t

// /// SlangSizeT
// SizeT :: distinct cffi.uint64_t

// /// SlangBool
// Bool :: distinct cffi.bool

// /// SlangSeverityIntegral
// SeverityIntegral :: distinct cffi.int

// /// SlangDiagnosticFlags
// DiagnosticFlags :: distinct cffi.int

// /// SlangBindableResourceIntegral
// BindableResourceIntegral :: distinct cffi.int

// /// SlangCompileTargetIntegral
// CompileTargetIntegral :: distinct cffi.int

// /// SlangContainerFormatIntegral
// ContainerFormatIntegral :: distinct cffi.int

// /// SlangPassThroughIntegral
// PassThroughIntegral :: distinct cffi.int

// /// SlangArchiveTypeIntegral
// ArchiveTypeIntegral :: distinct cffi.int

// /// SlangCompileFlags
// // CompileFlags :: distinct cffi.uint

// /// SlangTargetFlags
// TargetFlags :: distinct cffi.uint

// /// SlangFloatingPointModeIntegral
// FloatingPointModeIntegral :: distinct cffi.uint

// /// SlangLineDirectiveModeIntegral
// LineDirectiveModeIntegral :: distinct cffi.uint

// /// SlangSourceLanguageIntegral
// SourceLanguageIntegral :: distinct cffi.int

// /// SlangProfileIDIntegral
// ProfileIDIntegral :: distinct cffi.uint

// /// SlangCapabilityIDIntegral
// CapabilityIDIntegral :: distinct Int32

// /// SlangMatrixLayoutModeIntegral
// MatrixLayoutModeIntegral :: distinct cffi.uint

// /// SlangStageIntegral
// StageIntegral :: distinct UInt32

// /// SlangDebugInfoLevelIntegral
// DebugInfoLevelIntegral :: distinct UInt32

// /// SlangDebugInfoFormatIntegral
// DebugInfoFormatIntegral :: distinct UInt32

// /// SlangOptimizationLevelIntegral
// OptimizationLevelIntegral :: distinct UInt32

// /// SlangResult
// Result :: distinct cffi.int32_t

// /// SlangFuncPtr
// FuncPtr :: distinct proc "c" ()

// /// SlangPathTypeIntegral
// PathTypeIntegral :: distinct cffi.uint

// /// SlangWriterChannelIntegral
// WriterChannelIntegral :: distinct cffi.uint

// /// SlangWriterModeIntegral
// WriterModeIntegral :: distinct cffi.uint

// /// SlangSession
// Session :: distinct IGlobalSession

// /// SlangCompileRequest
// CompileRequest :: distinct ICompileRequest

// /// SlangDiagnosticCallback
// DiagnosticCallback :: distinct proc "c" (message: cstring, userData: rawptr)

// /// SlangReflection
// Reflection :: distinct ProgramLayout

// /// SlangReflectionEntryPoint
// ReflectionEntryPoint :: distinct EntryPointLayout

// /// SlangTypeKindIntegral
// TypeKindIntegral :: distinct cffi.uint

// /// SlangScalarTypeIntegral
// ScalarTypeIntegral :: distinct cffi.uint

// /// SlangDeclKindIntegral
// DeclKindIntegral :: distinct cffi.uint

// /// SlangResourceShapeIntegral
// ResourceShapeIntegral :: distinct cffi.uint

// /// SlangResourceAccessIntegral
// ResourceAccessIntegral :: distinct cffi.uint

// /// SlangParameterCategoryIntegral
// ParameterCategoryIntegral :: distinct cffi.uint

// /// SlangBindingTypeIntegral
// BindingTypeIntegral :: distinct UInt32

// /// SlangLayoutRulesIntegral
// LayoutRulesIntegral :: distinct UInt32

// /// SlangModifierIDIntegral
// ModifierIDIntegral :: distinct UInt32

// /// SlangImageFormatIntegral
// ImageFormatIntegral :: distinct UInt32

// /// SlangReflectionParameter
// ReflectionParameter :: distinct ReflectionVariableLayout

// /// slang::SessionFlags
// SessionFlags :: distinct cffi.uint32_t

// /// SlangSeverity
// Severity :: enum cffi.int {
// 	DISABLED = 0,
// 	NOTE     = 1,
// 	WARNING  = 2,
// 	ERROR    = 3,
// 	FATAL    = 4,
// 	INTERNAL = 5,
// }

// /// SlangBindableResourceType
// BindableResourceType :: enum cffi.int {
// 	NON_BINDABLE   = 0,
// 	TEXTURE        = 1,
// 	SAMPLER        = 2,
// 	UNIFORM_BUFFER = 3,
// 	STORAGE_BUFFER = 4,
// }

// /// SlangCompileTarget
// CompileTarget :: enum cffi.int {
// 	UNKNOWN                         = 0,
// 	NONE                            = 1,
// 	GLSL                            = 2,
// 	GLSL_VULKAN_DEPRECATED          = 3,
// 	GLSL_VULKAN_ONE_DESC_DEPRECATED = 4,
// 	HLSL                            = 5,
// 	SPIRV                           = 6,
// 	SPIRV_ASM                       = 7,
// 	DXBC                            = 8,
// 	DXBC_ASM                        = 9,
// 	DXIL                            = 10,
// 	DXIL_ASM                        = 11,
// 	C_SOURCE                        = 12,
// 	CPP_SOURCE                      = 13,
// 	HOST_EXECUTABLE                 = 14,
// 	SHADER_SHARED_LIBRARY           = 15,
// 	SHADER_HOST_CALLABLE            = 16,
// 	CUDA_SOURCE                     = 17,
// 	PTX                             = 18,
// 	CUDA_OBJECT_CODE                = 19,
// 	OBJECT_CODE                     = 20,
// 	HOST_CPP_SOURCE                 = 21,
// 	HOST_HOST_CALLABLE              = 22,
// 	CPP_PYTORCH_BINDING             = 23,
// 	METAL                           = 24,
// 	METAL_LIB                       = 25,
// 	METAL_LIB_ASM                   = 26,
// 	HOST_SHARED_LIBRARY             = 27,
// 	WGSL                            = 28,
// 	COUNT_OF                        = 29,
// }

// /// SlangContainerFormat
// ContainerFormat :: enum cffi.int {
// 	NONE         = 0,
// 	SLANG_MODULE = 1,
// }

// /// SlangPassThrough
// PassThrough :: enum cffi.int {
// 	NONE          = 0,
// 	FXC           = 1,
// 	DXC           = 2,
// 	GLSLANG       = 3,
// 	SPIRV_DIS     = 4,
// 	CLANG         = 5,
// 	VISUAL_STUDIO = 6,
// 	GCC           = 7,
// 	GENERIC_C_CPP = 8,
// 	NVRTC         = 9,
// 	LLVM          = 10,
// 	SPIRV_OPT     = 11,
// 	METAL         = 12,
// 	WGSL          = 13,
// 	COUNT_OF      = 14,
// }

// /// SlangArchiveType
// ArchiveType :: enum cffi.int {
// 	UNDEFINED    = 0,
// 	ZIP          = 1,
// 	RIFF         = 2,
// 	RIFF_DEFLATE = 3,
// 	RIFF_LZ4     = 4,
// 	COUNT_OF     = 5,
// }

// /// SlangFloatingPointMode
// FloatingPointMode :: enum cffi.uint {
// 	DEFAULT = 0,
// 	FAST    = 1,
// 	PRECISE = 2,
// }

// /// SlangLineDirectiveMode
// LineDirectiveMode :: enum cffi.uint {
// 	DEFAULT    = 0,
// 	NONE       = 1,
// 	STANDARD   = 2,
// 	GLSL       = 3,
// 	SOURCE_MAP = 4,
// }

// /// SlangSourceLanguage
// SourceLanguage :: enum cffi.int {
// 	UNKNOWN  = 0,
// 	SLANG    = 1,
// 	HLSL     = 2,
// 	GLSL     = 3,
// 	C        = 4,
// 	CPP      = 5,
// 	CUDA     = 6,
// 	SPIRV    = 7,
// 	METAL    = 8,
// 	WGSL     = 9,
// 	COUNT_OF = 10,
// }

// /// SlangProfileID
// ProfileID :: enum cffi.uint {
// 	UNKNOWN = 0,
// }

// /// SlangCapabilityID
// CapabilityID :: enum cffi.int {
// 	UNKNOWN = 0,
// }

// /// SlangMatrixLayoutMode
// MatrixLayoutMode :: enum cffi.uint {
// 	UNKNOWN      = 0,
// 	ROW_MAJOR    = 1,
// 	COLUMN_MAJOR = 2,
// }

// /// SlangStage
// Stage :: enum cffi.uint {
// 	NONE           = 0,
// 	VERTEX         = 1,
// 	HULL           = 2,
// 	DOMAIN         = 3,
// 	GEOMETRY       = 4,
// 	FRAGMENT       = 5,
// 	COMPUTE        = 6,
// 	RAY_GENERATION = 7,
// 	INTERSECTION   = 8,
// 	ANY_HIT        = 9,
// 	CLOSEST_HIT    = 10,
// 	MISS           = 11,
// 	CALLABLE       = 12,
// 	MESH           = 13,
// 	AMPLIFICATION  = 14,
// 	PIXEL          = 5,
// }

// /// SlangDebugInfoLevel
// DebugInfoLevel :: enum cffi.uint {
// 	NONE     = 0,
// 	MINIMAL  = 1,
// 	STANDARD = 2,
// 	MAXIMAL  = 3,
// }

// /// SlangDebugInfoFormat
// DebugInfoFormat :: enum cffi.uint {
// 	DEFAULT  = 0,
// 	C7       = 1,
// 	PDB      = 2,
// 	STABS    = 3,
// 	COFF     = 4,
// 	DWARF    = 5,
// 	COUNT_OF = 6,
// }

// /// SlangOptimizationLevel
// OptimizationLevel :: enum cffi.uint {
// 	NONE    = 0,
// 	DEFAULT = 1,
// 	HIGH    = 2,
// 	MAXIMAL = 3,
// }

// /// SlangPathType
// PathType :: enum cffi.uint {
// 	DIRECTORY = 0,
// 	FILE      = 1,
// }

// /// SlangWriterChannel
// WriterChannel :: enum cffi.uint {
// 	DIAGNOSTIC = 0,
// 	STD_OUTPUT = 1,
// 	STD_ERROR  = 2,
// 	COUNT_OF   = 3,
// }

// /// SlangWriterMode
// WriterMode :: enum cffi.uint {
// 	TEXT   = 0,
// 	BINARY = 1,
// }

// /// SlangReflectionGenericArgType
// ReflectionGenericArgType :: enum cffi.uint {
// 	TYPE = 0,
// 	INT  = 1,
// 	BOOL = 2,
// }

// /// SlangTypeKind
// TypeKind :: enum cffi.uint {
// 	NONE                   = 0,
// 	STRUCT                 = 1,
// 	ARRAY                  = 2,
// 	MATRIX                 = 3,
// 	VECTOR                 = 4,
// 	SCALAR                 = 5,
// 	CONSTANT_BUFFER        = 6,
// 	RESOURCE               = 7,
// 	SAMPLER_STATE          = 8,
// 	TEXTURE_BUFFER         = 9,
// 	SHADER_STORAGE_BUFFER  = 10,
// 	PARAMETER_BLOCK        = 11,
// 	GENERIC_TYPE_PARAMETER = 12,
// 	INTERFACE              = 13,
// 	OUTPUT_STREAM          = 14,
// 	MESH_OUTPUT            = 15,
// 	SPECIALIZED            = 16,
// 	FEEDBACK               = 17,
// 	POINTER                = 18,
// 	DYNAMIC_RESOURCE       = 19,
// 	COUNT                  = 20,
// }

// /// SlangScalarType
// ScalarType :: enum cffi.uint {
// 	NONE    = 0,
// 	VOID    = 1,
// 	BOOL    = 2,
// 	INT32   = 3,
// 	UINT32  = 4,
// 	INT64   = 5,
// 	UINT64  = 6,
// 	FLOAT16 = 7,
// 	FLOAT32 = 8,
// 	FLOAT64 = 9,
// 	INT8    = 10,
// 	UINT8   = 11,
// 	INT16   = 12,
// 	UINT16  = 13,
// 	INTPTR  = 14,
// 	UINTPTR = 15,
// }

// /// SlangDeclKind
// DeclKind :: enum cffi.uint {
// 	UNSUPPORTED_FOR_REFLECTION = 0,
// 	STRUCT                     = 1,
// 	FUNC                       = 2,
// 	MODULE                     = 3,
// 	GENERIC                    = 4,
// 	VARIABLE                   = 5,
// 	NAMESPACE                  = 6,
// }

// /// SlangResourceShape
// ResourceShape :: enum cffi.uint {
// 	BASE_SHAPE_MASK              = 15,
// 	NONE                         = 0,
// 	TEXTURE_1D                   = 1,
// 	TEXTURE_2D                   = 2,
// 	TEXTURE_3D                   = 3,
// 	TEXTURE_CUBE                 = 4,
// 	TEXTURE_BUFFER               = 5,
// 	STRUCTURED_BUFFER            = 6,
// 	BYTE_ADDRESS_BUFFER          = 7,
// 	UNKNOWN                      = 8,
// 	ACCELERATION_STRUCTURE       = 9,
// 	TEXTURE_SUBPASS              = 10,
// 	EXT_SHAPE_MASK               = 240,
// 	TEXTURE_FEEDBACK_FLAG        = 16,
// 	TEXTURE_SHADOW_FLAG          = 32,
// 	TEXTURE_ARRAY_FLAG           = 64,
// 	TEXTURE_MULTISAMPLE_FLAG     = 128,
// 	TEXTURE_1D_ARRAY             = 65,
// 	TEXTURE_2D_ARRAY             = 66,
// 	TEXTURE_CUBE_ARRAY           = 68,
// 	TEXTURE_2D_MULTISAMPLE       = 130,
// 	TEXTURE_2D_MULTISAMPLE_ARRAY = 194,
// 	TEXTURE_SUBPASS_MULTISAMPLE  = 138,
// }

// /// SlangResourceAccess
// ResourceAccess :: enum cffi.uint {
// 	NONE           = 0,
// 	READ           = 1,
// 	READ_WRITE     = 2,
// 	RASTER_ORDERED = 3,
// 	APPEND         = 4,
// 	CONSUME        = 5,
// 	WRITE          = 6,
// 	FEEDBACK       = 7,
// 	UNKNOWN        = 2147483647,
// }

// /// SlangParameterCategory
// ParameterCategory :: enum cffi.uint {
// 	NONE                          = 0,
// 	MIXED                         = 1,
// 	CONSTANT_BUFFER               = 2,
// 	SHADER_RESOURCE               = 3,
// 	UNORDERED_ACCESS              = 4,
// 	VARYING_INPUT                 = 5,
// 	VARYING_OUTPUT                = 6,
// 	SAMPLER_STATE                 = 7,
// 	UNIFORM                       = 8,
// 	DESCRIPTOR_TABLE_SLOT         = 9,
// 	SPECIALIZATION_CONSTANT       = 10,
// 	PUSH_CONSTANT_BUFFER          = 11,
// 	REGISTER_SPACE                = 12,
// 	GENERIC                       = 13,
// 	RAY_PAYLOAD                   = 14,
// 	HIT_ATTRIBUTES                = 15,
// 	CALLABLE_PAYLOAD              = 16,
// 	SHADER_RECORD                 = 17,
// 	EXISTENTIAL_TYPE_PARAM        = 18,
// 	EXISTENTIAL_OBJECT_PARAM      = 19,
// 	SUB_ELEMENT_REGISTER_SPACE    = 20,
// 	SUBPASS                       = 21,
// 	METAL_ARGUMENT_BUFFER_ELEMENT = 22,
// 	METAL_ATTRIBUTE               = 23,
// 	METAL_PAYLOAD                 = 24,
// 	COUNT                         = 25,
// 	METAL_BUFFER                  = 2,
// 	METAL_TEXTURE                 = 3,
// 	METAL_SAMPLER                 = 7,
// 	VERTEX_INPUT                  = 5,
// 	FRAGMENT_OUTPUT               = 6,
// 	COUNT_V1                      = 21,
// }

// /// SlangBindingType
// BindingType :: enum cffi.uint {
// 	UNKNOWN                            = 0,
// 	SAMPLER                            = 1,
// 	TEXTURE                            = 2,
// 	CONSTANT_BUFFER                    = 3,
// 	PARAMETER_BLOCK                    = 4,
// 	TYPED_BUFFER                       = 5,
// 	RAW_BUFFER                         = 6,
// 	COMBINED_TEXTURE_SAMPLER           = 7,
// 	INPUT_RENDER_TARGET                = 8,
// 	INLINE_UNIFORM_DATA                = 9,
// 	RAY_TRACING_ACCELERATION_STRUCTURE = 10,
// 	VARYING_INPUT                      = 11,
// 	VARYING_OUTPUT                     = 12,
// 	EXISTENTIAL_VALUE                  = 13,
// 	PUSH_CONSTANT                      = 14,
// 	MUTABLE_FLAG                       = 256,
// 	MUTABLE_TETURE                     = 258,
// 	MUTABLE_TYPED_BUFFER               = 261,
// 	MUTABLE_RAW_BUFFER                 = 262,
// 	BASE_MASK                          = 255,
// 	EXT_MASK                           = 65280,
// }

// /// SlangLayoutRules
// LayoutRules :: enum cffi.uint {
// 	DEFAULT                      = 0,
// 	METAL_ARGUMENT_BUFFER_TIER_2 = 1,
// }

// /// SlangModifierID
// ModifierID :: enum cffi.uint {
// 	SHARED         = 0,
// 	NO_DIFF        = 1,
// 	STATIC         = 2,
// 	CONST          = 3,
// 	EXPORT         = 4,
// 	EXTERN         = 5,
// 	DIFFERENTIABLE = 6,
// 	MUTATING       = 7,
// 	IN             = 8,
// 	OUT            = 9,
// 	INOUT          = 10,
// }

// /// SlangImageFormat
// ImageFormat :: enum cffi.uint {
// 	unknown        = 0,
// 	rgba32f        = 1,
// 	rgba16f        = 2,
// 	rg32f          = 3,
// 	rg16f          = 4,
// 	r11f_g11f_b10f = 5,
// 	r32f           = 6,
// 	r16f           = 7,
// 	rgba16         = 8,
// 	rgb10_a2       = 9,
// 	rgba8          = 10,
// 	rg16           = 11,
// 	rg8            = 12,
// 	r16            = 13,
// 	r8             = 14,
// 	rgba16_snorm   = 15,
// 	rgba8_snorm    = 16,
// 	rg16_snorm     = 17,
// 	rg8_snorm      = 18,
// 	r16_snorm      = 19,
// 	r8_snorm       = 20,
// 	rgba32i        = 21,
// 	rgba16i        = 22,
// 	rgba8i         = 23,
// 	rg32i          = 24,
// 	rg16i          = 25,
// 	rg8i           = 26,
// 	r32i           = 27,
// 	r16i           = 28,
// 	r8i            = 29,
// 	rgba32ui       = 30,
// 	rgba16ui       = 31,
// 	rgb10_a2ui     = 32,
// 	rgba8ui        = 33,
// 	rg32ui         = 34,
// 	rg16ui         = 35,
// 	rg8ui          = 36,
// 	r32ui          = 37,
// 	r16ui          = 38,
// 	r8ui           = 39,
// 	r64ui          = 40,
// 	r64i           = 41,
// }

// /// slang::CompilerOptionName
// CompilerOptionName :: enum cffi.int {
// 	MacroDefine                      = 0,
// 	DepFile                          = 1,
// 	EntryPointName                   = 2,
// 	Specialize                       = 3,
// 	Help                             = 4,
// 	HelpStyle                        = 5,
// 	Include                          = 6,
// 	Language                         = 7,
// 	MatrixLayoutColumn               = 8,
// 	MatrixLayoutRow                  = 9,
// 	ZeroInitialize                   = 10,
// 	IgnoreCapabilities               = 11,
// 	RestrictiveCapabilityCheck       = 12,
// 	ModuleName                       = 13,
// 	Output                           = 14,
// 	Profile                          = 15,
// 	Stage                            = 16,
// 	Target                           = 17,
// 	Version                          = 18,
// 	WarningsAsErrors                 = 19,
// 	DisableWarnings                  = 20,
// 	EnableWarning                    = 21,
// 	DisableWarning                   = 22,
// 	DumpWarningDiagnostics           = 23,
// 	InputFilesRemain                 = 24,
// 	EmitIr                           = 25,
// 	ReportDownstreamTime             = 26,
// 	ReportPerfBenchmark              = 27,
// 	ReportCheckpointIntermediates    = 28,
// 	SkipSPIRVValidation              = 29,
// 	SourceEmbedStyle                 = 30,
// 	SourceEmbedName                  = 31,
// 	SourceEmbedLanguage              = 32,
// 	DisableShortCircuit              = 33,
// 	MinimumSlangOptimization         = 34,
// 	DisableNonEssentialValidations   = 35,
// 	DisableSourceMap                 = 36,
// 	UnscopedEnum                     = 37,
// 	PreserveParameters               = 38,
// 	Capability                       = 39,
// 	DefaultImageFormatUnknown        = 40,
// 	DisableDynamicDispatch           = 41,
// 	DisableSpecialization            = 42,
// 	FloatingPointMode                = 43,
// 	DebugInformation                 = 44,
// 	LineDirectiveMode                = 45,
// 	Optimization                     = 46,
// 	Obfuscate                        = 47,
// 	VulkanBindShift                  = 48,
// 	VulkanBindGlobals                = 49,
// 	VulkanInvertY                    = 50,
// 	VulkanUseDxPositionW             = 51,
// 	VulkanUseEntryPointName          = 52,
// 	VulkanUseGLLayout                = 53,
// 	VulkanEmitReflection             = 54,
// 	GLSLForceScalarLayout            = 55,
// 	EnableEffectAnnotations          = 56,
// 	EmitSpirvViaGLSL                 = 57,
// 	EmitSpirvDirectly                = 58,
// 	SPIRVCoreGrammarJSON             = 59,
// 	IncompleteLibrary                = 60,
// 	CompilerPath                     = 61,
// 	DefaultDownstreamCompiler        = 62,
// 	DownstreamArgs                   = 63,
// 	PassThrough                      = 64,
// 	DumpRepro                        = 65,
// 	DumpReproOnError                 = 66,
// 	ExtractRepro                     = 67,
// 	LoadRepro                        = 68,
// 	LoadReproDirectory               = 69,
// 	ReproFallbackDirectory           = 70,
// 	DumpAst                          = 71,
// 	DumpIntermediatePrefix           = 72,
// 	DumpIntermediates                = 73,
// 	DumpIr                           = 74,
// 	DumpIrIds                        = 75,
// 	PreprocessorOutput               = 76,
// 	OutputIncludes                   = 77,
// 	ReproFileSystem                  = 78,
// 	SerialIr                         = 79,
// 	SkipCodeGen                      = 80,
// 	ValidateIr                       = 81,
// 	VerbosePaths                     = 82,
// 	VerifyDebugSerialIr              = 83,
// 	NoCodeGen                        = 84,
// 	FileSystem                       = 85,
// 	Heterogeneous                    = 86,
// 	NoMangle                         = 87,
// 	NoHLSLBinding                    = 88,
// 	NoHLSLPackConstantBufferElements = 89,
// 	ValidateUniformity               = 90,
// 	AllowGLSL                        = 91,
// 	EnableExperimentalPasses         = 92,
// 	ArchiveType                      = 93,
// 	CompileStdLib                    = 94,
// 	Doc                              = 95,
// 	IrCompression                    = 96,
// 	LoadStdLib                       = 97,
// 	ReferenceModule                  = 98,
// 	SaveStdLib                       = 99,
// 	SaveStdLibBinSource              = 100,
// 	TrackLiveness                    = 101,
// 	LoopInversion                    = 102,
// 	ParameterBlocksUseRegisterSpaces = 103,
// 	CountOfParsableOptions           = 104,
// 	DebugInformationFormat           = 105,
// 	VulkanBindShiftAll               = 106,
// 	GenerateWholeProgram             = 107,
// 	UseUpToDateBinaryModule          = 108,
// 	EmbedDownstreamIR                = 109,
// 	ForceDXLayout                    = 110,
// 	CountOf                          = 111,
// }

// /// slang::CompilerOptionValueKind
// CompilerOptionValueKind :: enum cffi.int {
// 	Int    = 0,
// 	String = 1,
// }

// /// slang::TypeReflection::Kind
// TypeReflectionKind :: enum cffi.int {
// 	None                 = 0,
// 	Struct               = 1,
// 	Array                = 2,
// 	Matrix               = 3,
// 	Vector               = 4,
// 	Scalar               = 5,
// 	ConstantBuffer       = 6,
// 	Resource             = 7,
// 	SamplerState         = 8,
// 	TextureBuffer        = 9,
// 	ShaderStorageBuffer  = 10,
// 	ParameterBlock       = 11,
// 	GenericTypeParameter = 12,
// 	Interface            = 13,
// 	OutputStream         = 14,
// 	Specialized          = 16,
// 	Feedback             = 17,
// 	Pointer              = 18,
// 	DynamicResource      = 19,
// }

// /// slang::TypeReflection::ScalarType
// TypeReflectionScalarType :: enum cffi.uint {
// 	None    = 0,
// 	Void    = 1,
// 	Bool    = 2,
// 	Int32   = 3,
// 	UInt32  = 4,
// 	Int64   = 5,
// 	UInt64  = 6,
// 	Float16 = 7,
// 	Float32 = 8,
// 	Float64 = 9,
// 	Int8    = 10,
// 	UInt8   = 11,
// 	Int16   = 12,
// 	UInt16  = 13,
// }

// /// slang::SpecializationArg::Kind
// SpecializationArgKind :: enum cffi.int {
// 	Unknown = 0,
// 	Type    = 1,
// }

// /// slang::CompilerOptionValue
// CompilerOptionValue :: struct #align (8) {
// 	kind:         CompilerOptionValueKind,
// 	intValue0:    cffi.int32_t,
// 	intValue1:    cffi.int32_t,
// 	stringValue0: cstring,
// 	stringValue1: cstring,
// }
// #assert(size_of(CompilerOptionValue) == 32)

// /// slang::CompilerOptionEntry
// CompilerOptionEntry :: struct #align (8) {
// 	name:  CompilerOptionName,
// 	value: CompilerOptionValue,
// }
// #assert(size_of(CompilerOptionEntry) == 40)

// /// SlangUUID
// UUID :: struct #align (4) {
// 	data1: cffi.uint32_t,
// 	data2: cffi.uint16_t,
// 	data3: cffi.uint16_t,
// 	data4: [8]cffi.uint8_t,
// }
// #assert(size_of(UUID) == 16)

// /// SlangTerminatedChars
// TerminatedChars :: struct {
// 	chars: [1]cffi.char,
// }
// #assert(size_of(TerminatedChars) == 1)

// /// SlangProgramLayout
// ProgramLayout :: struct {}

// /// SlangEntryPoint
// EntryPoint :: struct {}

// /// SlangEntryPointLayout
// EntryPointLayout :: struct {}

// /// SlangReflectionDecl
// ReflectionDecl :: struct {}

// /// SlangReflectionModifier
// ReflectionModifier :: struct {}

// /// SlangReflectionType
// ReflectionType :: struct {}

// /// SlangReflectionTypeLayout
// ReflectionTypeLayout :: struct {}

// /// SlangReflectionVariable
// ReflectionVariable :: struct {}

// /// SlangReflectionVariableLayout
// ReflectionVariableLayout :: struct {}

// /// SlangReflectionTypeParameter
// ReflectionTypeParameter :: struct {}

// /// SlangReflectionUserAttribute
// ReflectionUserAttribute :: struct {}

// /// SlangReflectionFunction
// ReflectionFunction :: struct {}

// /// SlangReflectionGeneric
// ReflectionGeneric :: struct {}

// /// slang::SessionDesc
// SessionDesc :: struct #align (8) {
// 	structureSize:            cffi.size_t,
// 	targets:                  ^TargetDesc,
// 	targetCount:              Int,
// 	flags:                    SessionFlags,
// 	defaultMatrixLayoutMode:  MatrixLayoutMode,
// 	searchPaths:              ^cstring,
// 	searchPathCount:          Int,
// 	preprocessorMacros:       ^PreprocessorMacroDesc,
// 	preprocessorMacroCount:   Int,
// 	fileSystem:               ^IFileSystem,
// 	enableEffectAnnotations:  cffi.bool,
// 	allowGLSLSyntax:          cffi.bool,
// 	compilerOptionEntries:    ^CompilerOptionEntry,
// 	compilerOptionEntryCount: cffi.uint32_t,
// }
// #assert(size_of(SessionDesc) == 96)

// /// slang::SpecializationArg
// SpecializationArg :: struct #align (8) {
// 	kind:    SpecializationArgKind,
// 	using _: struct #raw_union {
// 		type: ^TypeReflection,
// 	},
// }
// #assert(size_of(SpecializationArg) == 16)

// /// slang::TargetDesc
// TargetDesc :: struct #align (8) {
// 	structureSize:               cffi.size_t,
// 	format:                      CompileTarget,
// 	profile:                     ProfileID,
// 	flags:                       TargetFlags,
// 	floatingPointMode:           FloatingPointMode,
// 	lineDirectiveMode:           LineDirectiveMode,
// 	forceGLSLScalarBufferLayout: cffi.bool,
// 	compilerOptionEntries:       ^CompilerOptionEntry,
// 	compilerOptionEntryCount:    cffi.uint32_t,
// }
// #assert(size_of(TargetDesc) == 48)

// /// slang::PreprocessorMacroDesc
// PreprocessorMacroDesc :: struct #align (8) {
// 	name:  cstring,
// 	value: cstring,
// }
// #assert(size_of(PreprocessorMacroDesc) == 16)

// /// SlangReflectionGenericArg
// ReflectionGenericArg :: struct #raw_union #align (8) {
// 	typeVal: ^ReflectionType,
// 	intVal:  cffi.int64_t,
// 	boolVal: cffi.bool,
// }
// #assert(size_of(ReflectionGenericArg) == 8)
