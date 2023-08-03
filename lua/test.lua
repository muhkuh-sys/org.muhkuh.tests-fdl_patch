local class = require 'pl.class'
local TestClassFDLBase = require 'test_class_fdl_base'
local TestClassFDL = class(TestClassFDLBase)

--- TestClassFDL contructor.
-- The class TestClassFDL is derived from the TestClassFDLBase. The constructor
-- initializes the base class and defines the parameter.
-- @param strTestName Name of the testcase. This is the value of the "name" attribute in the tests.xml.
-- @param uiTestCase The number of the test case.
-- @param tLogWriter The log writer class is used to create a log target with a prefix of "[Test {uiTestCase}] ",
--                   e.g. "[Test 01] " for the test with number 1.
-- @param strLogLevel The log level filters log messages.
function TestClassFDL:_init(strTestName, uiTestCase, tLogWriter, strLogLevel)
  self:super(strTestName, uiTestCase, tLogWriter, strLogLevel)

  local P = self.P
  self:__parameter {
    P:P('plugin', 'A pattern for the plugin to use.'):
      required(false),

    P:P('plugin_options', 'Plugin options as a JSON object.'):
      required(false),

    P:P('fdl_template_file', 'The FDL template which will be patched.'):
      required(true),

    P:U32('manufacturer', 'The manufacturer ID of the board.'):
      required(true),

    P:U32('devicenr', 'The device number of the board.'):
      required(true),

    P:U32('serial', 'The serial number of the board.'):
      required(true),

    P:U32('hwrev', 'The hardware revision of the board.'):
      required(true),

    P:U32('deviceclass', 'The device class of the board.'):
      required(true),

    P:U32('hwcomp', 'The hardware compatibility of the board.'):
      required(true),

    P:P('mac_dp', 'The data provider item for the MAC adresses.'):
      required(false),

    P:U8('mac_com', 'The number of MAC addresses on the COM side.'):
      default(0):
      required(true),

    P:U8('mac_app', 'The number of MAC addresses on the APP side.'):
      default(0):
      required(true)
  }
end



function TestClassFDL:run()
  local atParameter = self.atParameter
  local tLog = self.tLog

  ----------------------------------------------------------------------
  --
  -- Parse the parameters and collect all options.
  --
  local strPluginPattern = atParameter['plugin']:get()
  local strPluginOptions = atParameter['plugin_options']:get()
  local strFdlTemplateFile = atParameter['fdl_template_file']:get()
  local ulManufacturer = atParameter['manufacturer']:get()
  local ulDeviceNr = atParameter['devicenr']:get()
  local ulSerial = atParameter['serial']:get()
  local ulHwRev = atParameter['hwrev']:get()
  local ulDeviceClass = atParameter['deviceclass']:get()
  local ulHwComp = atParameter['hwcomp']:get()
  local strMacDp = atParameter['mac_dp']:get()
  local ulMacCom = atParameter['mac_com']:get()
  local ulMacApp = atParameter['mac_app']:get()

  -- Read and parse the FDL template file.
  local tFDLContents = self:readTemplate(strFdlTemplateFile)

  -- Collect all patch data.
  -- Please note that MAC addresses should be added with the requestMacs method.
  -- Add more fields like described here: https://github.com/muhkuh-sys/org.muhkuh.tools-fdltool#patch-an-fdl
  local tPatches = {
    tBasicDeviceData = {
      usManufacturerID = ulManufacturer,
      ulDeviceNumber = ulDeviceNr,
      ulSerialNumber = ulSerial,
      ucHardwareRevisionNumber = ulHwRev,
      usDeviceClassificationNumber = ulDeviceClass,
      ucHardwareCompatibilityNumber = ulHwComp
    },
--    tProductIdentification = {
--      usUSBVendorID = 0x1939,
--      usUSBProductID = 0x1234,
--      aucUSBVendorName = "Hilscher",
--      aucUSBProductName = "netX powered electrical USB sheep"
--    },
--    tOEMIdentification = {
--      ulOEMDataOptionFlags = 0x00000000,
--      aucOEMSerialNumber = "0123456789",
--      aucOEMOrderNumber = "XYZ",
--      aucOEMHardwareRevision = "01234",
--      aucOEMProductionDateTime = "long long ago"
--    }
  }

  -- Set the production date.
  -- Please note that the production date must be set before the MACs are requested.
  self:setProductionDate(tPatches)

  -- Request the MAC addresses and add them to the patch data.
  self:requestMacs(tFDLContents, tPatches, strMacDp, ulMacCom, ulMacApp)

  -- Apply the patch to the FDL template.
  self:applyPatchData(tFDLContents, tPatches)

  -- Open the connection to the netX.
  local tPlugin = self:getPlugin(strPluginPattern, strPluginOptions)

  -- Write the plugin to the default position.
  -- Alternatively you can specify a positon with the optional third argument.
  -- It must be a table with "bus", "unit", "chipselect" and "offset" elements.
  -- Example:
  --   self:writeFDL(tFDLContents, tPlugin, { bus='IFlash', unit=0, chipselect=0, offset=0x2000 })
  self:writeFDL(tFDLContents, tPlugin)

  tLog.info('')
  tLog.info(' #######  ##    ## ')
  tLog.info('##     ## ##   ##  ')
  tLog.info('##     ## ##  ##   ')
  tLog.info('##     ## #####    ')
  tLog.info('##     ## ##  ##   ')
  tLog.info('##     ## ##   ##  ')
  tLog.info(' #######  ##    ## ')
  tLog.info('')
end


return function(ulTestID, tLogWriter, strLogLevel) return TestClassFDL('@NAME@', ulTestID, tLogWriter, strLogLevel) end
