local class = require 'pl.class'
local TestClassFDLBase = require 'test_class_fdl_base'
local TestClassFDL = class(TestClassFDLBase)

--- TestClassFDL contructor.
-- The class TestClassFDL is derived from the TestClassFDLBase. The constructor
-- initializes the base class and defines the parameter.
-- @param strTestName Name of the testcase. This is the value of the "name" attribute in the tests.xml.
-- @param uiTestCase The number of the test case.
-- @param tLogWriter The log writer class is used to create a log target with a prefix of "[Test {uiTestCase}] ", e.g. "[Test 01] " for the test with number 1.
-- @param strLogLevel The log level filters log messages.
function TestClassFDL:_init(strTestName, uiTestCase, tLogWriter, strLogLevel)
  self:super(strTestName, uiTestCase, tLogWriter, strLogLevel)

  local P = self.P
  self:__parameter {
    P:P('plugin', 'A pattern for the plugin to use.'):
      required(false),

    P:P('plugin_options', 'Plugin options as a JSON object.'):
      required(false),

    P:P('wfp_dp', 'The data provider item for the WFP file to flash.'):
      required(true),

    P:P('wfp_conditions', 'The conditions for the FDL file in the WFP.'):
      required(true):
      default(''),

    P:SC('wfp_bus', 'The bus for the FDL entry in the WFP.'):
      required(false):
      constraint('Parflash', 'Spi', 'IFlash'),

    P:U32('wfp_unit', 'The unit for the FDL entry in the WFP.'):
      required(false),

    P:U8('wfp_chip_select', 'The chip select for the FDL entry in the WFP.'):
      required(false),

    P:U32('wfp_offset', 'The offset for the FDL entry in the WFP.'):
      required(false),

    P:P('mac_dp', 'The data provider item for the MAC adresses.'):
    required(false),

    P:U32('Manufacturer', 'The manufacturer number.'):
    required(false),

    P:U32('serial', 'The serial number of the board.'):
      required(true),

    P:U32('DeviceNr', 'The Devicenumber of the board.'):
      required(true),

    P:U32('HwRev', 'The hardware revision number of the board.'):
      required(true),

    P:U32('DeviceClass', 'The device classification number of the board.'):
      required(false),

    P:U32('HwComp', 'The hardware compatibility number of the board.'):
      required(false),
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

  local strDataProviderItem = atParameter['wfp_dp']:get()
  local strWfpConditions = atParameter['wfp_conditions']:get()
  local strWfp_Bus = atParameter['wfp_bus']:get()
  local ulWFP_FDL_Unit = atParameter['wfp_unit']:get()
  local ulWFP_FDL_ChipSelect = atParameter['wfp_chip_select']:get()
  local ulWFP_FDL_Offset = atParameter['wfp_offset']:get()

  local ulManufacturer = atParameter['Manufacturer']:get()
  local ulSerial = atParameter['serial']:get()
  local ulDeviceNr = atParameter['DeviceNr']:get()
  local ulHwRev = atParameter['HwRev']:get()
  local ulDeviceClass = atParameter['DeviceClass']:get()
  local ulHwComp = atParameter['HwComp']:get()

  local strMacDp = atParameter['mac_dp']:get()

  -- Open the connection to the netX.
  local tPlugin = self:getPlugin(strPluginPattern, strPluginOptions)

  -- Parse the wfp_dp option.
  local tItem = _G.tester:getDataItem(strDataProviderItem)
  if tItem==nil then
    local strMsg = string.format('No data provider item found with the name "%s".', strDataProviderItem)
    tLog.error(strMsg)
    error(strMsg)
  end
  local strWfpFile = tItem.path
  if strWfpFile==nil then
    local strMsg = string.format(
      'The data provider item "%s" has no "path" attribute. Is this really a suitable provider for a WFP file?',
      strDataProviderItem
    )
    tLog.error(strMsg)
    error(strMsg)
  end

  -- Read and parse the FDL template file.
  local tFDLContents = self:readTemplateFromWFP(tPlugin, strWfpFile, strWfpConditions, strWfp_Bus, ulWFP_FDL_Unit, ulWFP_FDL_ChipSelect, ulWFP_FDL_Offset)

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
    }
  }

  -- Set the production date.
  -- Please note that the production date must be set before the MACs are requested.
  self:setProductionDate(tPatches)

  -- First check HREP for existing MAC-Configuration.
  local ulMacCom, ulMacApp
  local tItemConfig = {}
  tLog.debug('Checking %s, if a data provider item for the MAC addresses is configured...', strMacDp)
  if strMacDp == nil then
    tLog.debug('No test.xml parameter specified for the MAC addresses. Skipping MAC address request.')
  else
    -- Check if the data provider item config exists.
    tItemConfig = _G.tester:getDataItemCfg(strMacDp)
    --pl.pretty.dump(tItemConfig)
    if tItemConfig==nil then
      local strMsg = string.format('No data provider item found with the name "%s".', strMacDp)
      tLog.error(strMsg)
      error(strMsg)
    else
      -- Check if the data provider item for the MAC addresses exists and has the necessary configuration.
      if tItemConfig.MACQUANTITY == nil then
        local strMsg = string.format(
          'The data provider item "%s" has no "MACQUANTITY" configuration. Is this really a suitable provider for the MAC addresses?',
          strMacDp
        )
        tLog.error(strMsg)
        error(strMsg)
      else
        -- Extract COM and APP Quantity
        local atMacQuantity = tItemConfig.MACQUANTITY
        if atMacQuantity.COM~=nil then
          ulMacCom = tonumber(atMacQuantity.COM)
          if ulMacCom==nil then
            local strMsg = string.format('Invalid MAC quantity, "COM" is not a number: %s', tostring(atMacQuantity.COM))
            tLog.error(strMsg)
            error(strMsg)
          end
        end

        if atMacQuantity.APP~=nil then
          ulMacApp = tonumber(atMacQuantity.APP)
          if ulMacApp==nil then
            local strMsg = string.format('Invalid MAC quantity, "APP" is not a number: %s', tostring(atMacQuantity.APP))
            tLog.error(strMsg)
            error(strMsg)
          end
        end

        tLog.debug(string.format('MAC quantity for COM: %d, APP: %d', ulMacCom, ulMacApp))

        -- Request the MAC addresses and add them to the patch data.
        -- func already checks if mac adress count > 0.
        self:requestMacs(tFDLContents, tPatches, strMacDp, ulMacCom, ulMacApp)
      end
    end
  end



  -- Apply the patch to the FDL template.
  self:applyPatchData(tFDLContents, tPatches)

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


return TestClassFDL
