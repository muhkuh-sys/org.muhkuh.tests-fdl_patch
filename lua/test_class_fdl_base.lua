local class = require 'pl.class'
local TestClass = require 'test_class'
local TestClassFDLBase = class(TestClass)


--- TestClassFDLBase contructor.
-- The class TestClassFDLBase is derived from the TestClass. The constructor
-- initializes the base class.
-- @param strTestName Name of the testcase. This is the value of the "name" attribute in the tests.xml.
-- @param uiTestCase The number of the test case.
-- @param tLogWriter The log writer class is used to create a log target with a prefix of "[Test {uiTestCase}] ",
--                   e.g. "[Test 01] " for the test with number 1.
-- @param strLogLevel The log level filters log messages.
function TestClassFDLBase:_init(strTestName, uiTestCase, tLogWriter, strLogLevel)
  self:super(strTestName, uiTestCase, tLogWriter, strLogLevel)

  -- Keep the log writer for the WFP control.
  self.tLogWriter = tLogWriter

  local tFlasher = require 'flasher'(self.tLog)
  self.tFlasher = tFlasher
  self.json = require 'dkjson'

  self.atName2Bus = {
    ['Parflash'] = tFlasher.BUS_Parflash,
    ['Spi']      = tFlasher.BUS_Spi,
    ['IFlash']   = tFlasher.BUS_IFlash
  }

  local romloader = _G.romloader
  self.atDefaultFDLPosition = {
    [romloader.ROMLOADER_CHIPTYP_NETX4000_FULL] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX4100_SMALL] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX4000_RELAXED] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX500] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX100] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX90_MPW] = {
      bus = tFlasher.BUS_IFlash,
      unit = 3,
      chipselect = 0,
      offset = 0x2000
    },

    [romloader.ROMLOADER_CHIPTYP_NETX90] = {
      bus = tFlasher.BUS_IFlash,
      unit = 3,
      chipselect = 0,
      offset = 0x2000
    },

    [romloader.ROMLOADER_CHIPTYP_NETX90B] = {
      bus = tFlasher.BUS_IFlash,
      unit = 3,
      chipselect = 0,
      offset = 0x2000
    },

    [romloader.ROMLOADER_CHIPTYP_NETX56] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX56B] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX50] = {
      -- No default FDL position known yet...
    },

    [romloader.ROMLOADER_CHIPTYP_NETX10] = {
      -- No default FDL position known yet...
    }
  }
end



function TestClassFDLBase:requestMacs(tFDLContents, tPatchData, strDataProviderItem, ulMacCom, ulMacApp)
  local tLog = self.tLog

  -- Check the number of requested MACs.
  if ulMacCom<0 or ulMacCom>8 then
    error('The mac_com parameter must be in the range [0, 8].')
  end
  if ulMacApp<0 or ulMacApp>4 then
    error('The mac_app parameter must be in the range [0, 4].')
  end

  -- Create new tables for the COM and APP MACs if the patch data has no entries yet.
  local atMacCOM = tPatchData.atMacCOM
  if atMacCOM==nil then
    atMacCOM = {}
    tPatchData.atMacCOM = atMacCOM
  end
  local atMacAPP = tPatchData.atMacAPP
  if atMacAPP==nil then
    atMacAPP = {}
    tPatchData.atMacAPP = atMacAPP
  end

  -- Get all fields from the FDL which are required for a MAC request.
  local tPatch_BasicDeviceData = tPatchData.tBasicDeviceData or {}
  local ulManufacturer = tPatch_BasicDeviceData.usManufacturerID or
                         tFDLContents.tBasicDeviceData.usManufacturerID
  local ulDeviceNr =     tPatch_BasicDeviceData.ulDeviceNumber or
                         tFDLContents.tBasicDeviceData.ulDeviceNumber
  local ulHwRev =        tPatch_BasicDeviceData.ucHardwareRevisionNumber or
                         tFDLContents.tBasicDeviceData.ucHardwareRevisionNumber
  local ulDeviceClass =  tPatch_BasicDeviceData.usDeviceClassificationNumber or
                         tFDLContents.tBasicDeviceData.usDeviceClassificationNumber
  local ulHwComp =       tPatch_BasicDeviceData.ucHardwareCompatibilityNumber or
                         tFDLContents.tBasicDeviceData.ucHardwareCompatibilityNumber

  -- The serial number and the production date are only present in the patch data.
  local ulSerial = tPatch_BasicDeviceData.ulSerialNumber
  if ulSerial==nil then
    error('The patch data does not contain a serial number.')
  end

  -- Request all MAC addresses.
  local uiMacTotal = ulMacCom + ulMacApp
  local atBoardInfo
  if uiMacTotal>0 then
    local atAttr = {
      MANUFACTURER = ulManufacturer,
      DEVICENR = ulDeviceNr,
      SERIALNR = ulSerial,
      HWREV = ulHwRev,
      DEVICECLASS = ulDeviceClass,
      HWCOMPATIBILITY = ulHwComp,
      NUMBEROFMACS = uiMacTotal
    }
    local tDataItem, tMergedParameter = _G.tester:getDataItem(strDataProviderItem, atAttr)
    if tDataItem==nil then
      local strMsg = string.format('No data provider item found with the name "%s".', strDataProviderItem)
      tLog.error(strMsg)
      error(strMsg)
    end
    atBoardInfo = tDataItem.board_info
    if atBoardInfo==nil then
      local strMsg = string.format(
        'The data item "%s" has no "board_info" attribute. Is this really providing MAC addresses?',
        strDataProviderItem
      )
      tLog.error(strMsg)
      error(strMsg)
    end

    local astrPrettyMacs = {}
    local uiMacCnt = 1
    if ulMacCom>0 then
      for uiCnt=1,ulMacCom do
        local strMac = atBoardInfo[uiMacCnt].mac_pretty
        if strMac==nil then
          local strMsg = string.format(
            'The data provider returned no pretty MAC for entry %d.',
            uiMacCnt
          )
          tLog.error(strMsg)
          error(strMsg)
        end
        uiMacCnt = uiMacCnt + 1

        atMacCOM[uiCnt] = { aucMAC=strMac }
        tLog.debug('Patch FDL field "atMacCOM[%d].aucMAC = %s', uiCnt, strMac)
        table.insert(astrPrettyMacs, strMac)
      end
    end
    if ulMacApp>0 then
      for uiCnt=1,ulMacApp do
        local strMac = atBoardInfo[uiMacCnt].mac_pretty
        if strMac==nil then
          local strMsg = string.format(
            'The data provider returned no pretty MAC for entry %d.',
            uiMacCnt
          )
          tLog.error(strMsg)
          error(strMsg)
        end
        uiMacCnt = uiMacCnt + 1

        atMacAPP[uiCnt] = { aucMAC=strMac }
        tLog.debug('Patch FDL field "atMacAPP[%d].aucMAC = %s', uiCnt, strMac)
        table.insert(astrPrettyMacs, strMac)
      end
    end

    -- Get the group from the merged parameters.
    local strGroup = tMergedParameter.GROUP

    -- Get the production date from the first reserved MAC.
    local usProductionDate = atBoardInfo[1].productiondate

    -- Log all MACs.
    _G.tester:sendLogEvent('muhkuh.attribute.mac', {
      attributes = {
        deviceclass = ulDeviceClass,
        devicenr = ulDeviceNr,
        group = strGroup,
        hwcompaibility = ulHwComp,
        hwrev = ulHwRev,
        manufacturer = ulManufacturer,
        productiondate = usProductionDate,
        serialnr = ulSerial
      },
      mac = astrPrettyMacs
    })
  end
end


--- Re-use an existing connection to a netX or try to open a new one.
-- @parameter strPluginPattern The pattern for the plugin.
-- @parameter strPluginOptions JSON encoded options for the plugin or nil if no options should be applied.
-- @return The open plugin.
function TestClassFDLBase:getPlugin(strPluginPattern, strPluginOptions)
  local json = self.json
  local pl = self.pl
  local tLog = self.tLog

  -- Parse the plugin options.
  local atPluginOptions = {}
  if strPluginOptions~=nil then
    local tJson, uiPos, strJsonErr = json.decode(strPluginOptions)
    if tJson==nil then
      tLog.warning('Ignoring invalid plugin options. Error parsing the JSON: %d %s', uiPos, strJsonErr)
    else
      atPluginOptions = tJson
    end
  end

  -- Re-use an existing connection or try open a new one.
  local tPlugin = _G.tester:getCommonPlugin(strPluginPattern, atPluginOptions)
  if tPlugin==nil then
    local strPrettyOptions = pl.pretty.write(atPluginOptions)
    local strMsg = string.format(
      'Failed to establish a connection to the netX with pattern "%s" and options "%s".',
      strPluginPattern,
      strPrettyOptions
    )
    tLog.error(strMsg)
    error(strMsg)
  end

  return tPlugin
end


--- Write FDL data to a flash memory.
-- The function encodes the FDL data to binary and writes it to a flash memory connected to a netX.
-- The netX is selected by a plugin connection returned by the "getPlugin" method.
-- The position in the flash memory can be specified with the optional third parameter. If the third
-- parameter is present, it must be a table with the entries "bus", "unit", "chipselect" and "offset".
-- All missing entries are taken from an internal list of default FDL positions.
-- @parameter tFDLContents The FDL contents to write.
-- @parameter tPlugin The plugin connection to the netX.
-- @parameter tFlashPosition Optional table to overwrite the default FDL position.
-- @return noting
function TestClassFDLBase:writeFDL(tFDLContents, tPlugin, tFlashPosition, strExtraData)
  tFlashPosition = tFlashPosition or {}
  local tLog = self.tLog

  -- Check which attributes are missing in the flash position.
  local astrRequiredAttributes = {
    'bus',
    'unit',
    'chipselect',
    'offset'
  }
  local astrWhatIsMissing = {}
  local bSomethingIsMissing = false
  for _, strAttribute in ipairs(astrRequiredAttributes) do
    if tFlashPosition[strAttribute]==nil then
      table.insert(astrWhatIsMissing, strAttribute)
      bSomethingIsMissing = true
    end
  end

  -- Set a default position if one of the position parameters is missing.
  if bSomethingIsMissing~=false then
    tLog.debug('The following attributes for the FDL position are missing: %s', table.concat(astrWhatIsMissing, ', '))

    -- The FDL position depends on the chip type.
    -- Check if this test case has default values for the connected chip type.
    local tChipType = tPlugin:GetChiptyp()
    local strChipType = tPlugin:GetChiptypName(tChipType)
    tLog.debug('Trying to get the default FDL position for %s (%s)', strChipType, tostring(tChipType))
    local tAttributes = self.atDefaultFDLPosition[tChipType]
    if tAttributes==nil then
      local strMsg = string.format(
        'Trying to get the default FDL position for chip type %s (%s), but this chip type is not known by the test.',
        strChipType,
        tostring(tChipType)
      )
      tLog.error(strMsg)
      error(strMsg)
    end
    -- Set all missing FDL position attributes from the defaults.
    -- Throw an error if no default is provided for one attribute.
    for _, strAttribute in ipairs(astrRequiredAttributes) do
      if tFlashPosition[strAttribute]==nil then
        local tDefaultValue = tAttributes[strAttribute]
        if tDefaultValue==nil then
          local strMsg = string.format(
            'No default "%s" value found for chip type %s (%s).',
            strChipType,
            tostring(tChipType)
          )
          tLog.error(strMsg)
          error(strMsg)
        end
        tFlashPosition[strAttribute] = tDefaultValue
      end
    end
  end

  -- Create a new FDL instance.
  local tFDL = require 'fdl'(tLog)

  -- Get any data after the FDL.
  local sizBinaryFdlMaxInBytes = tFDL.sizBinaryFdlMaxInBytes or 1024

  -- Encode the FDL to binary.
  local strNewFDL = tFDL:fdl2bin(tFDLContents)
  -- If extra data exists, pad the FDL and append it.
  if strExtraData~=nil and strExtraData~='' then
    local sizNewFdl = string.len(strNewFDL)
    if sizNewFdl<sizBinaryFdlMaxInBytes then
      -- Pad the new FDL with 0xFF.
      strNewFDL = strNewFDL .. string.rep(string.char(0xff), sizBinaryFdlMaxInBytes-sizNewFdl)
    end
    -- Append the extra data.
    strNewFDL = strNewFDL .. strExtraData
  end

  -- Add the FDL contents to the log.
  local atEventData = {
    fdl = tFDLContents,
    bin =_G.tester:asciiArmor(strNewFDL)
  }
  _G.tester:sendLogEvent('muhkuh.attribute.fdl', atEventData)

  -- Install the flasher binary.

  local tFlasher = require 'flasher'(tLog)

  -- Download the binary.
  local aAttr = tFlasher:download(tPlugin, 'netx/')

  -- Flash the FDL to INTFLASH0, offset 0x2000.
  local tBus = tFlashPosition.bus
  local ulUnit = tFlashPosition.unit
  local ulChipSelect = tFlashPosition.chipselect
  local ulOffset = tFlashPosition.offset
  local strData = strNewFDL
  tLog.debug('Flash FDL to %d/%d/%d/0x%08x.', tBus, ulUnit, ulChipSelect, ulOffset)
  -- Detect the device.
  local fOk = tFlasher:detect(tPlugin, aAttr, tBus, ulUnit, ulChipSelect)
  if fOk~=true then
    error("Failed to detect the device!")
  end
  -- Erase the area.
  local strMsg
  fOk, strMsg = tFlasher:eraseArea(tPlugin, aAttr, ulOffset, strData:len())
  assert(fOk, strMsg or "Error while erasing area")

  fOk, strMsg = tFlasher:flashArea(tPlugin, aAttr, ulOffset, strData)
  assert(fOk, strMsg or "Error while programming area")
end


function TestClassFDLBase:readTemplate(strFdlTemplateFile)
  local tLog = self.tLog

  if strFdlTemplateFile==nil then
    local strMsg = 'No FDL template file specified.'
    tLog.error(strMsg)
    error(strMsg)
  end
  -- Does the file exist?
  if self.pl.path.exists(strFdlTemplateFile)~=strFdlTemplateFile then
    local strMsg = string.format('The FDL template file does not exist: "%s"', strFdlTemplateFile)
    tLog.error(strMsg)
    error(strMsg)
  end

  -- Read the FDL template.
  local strFdlTemplate, strError = self.pl.utils.readfile(strFdlTemplateFile, true)
  if strFdlTemplate==nil then
    local strMsg = string.format('Failed to read the FDL template from "%s": %s', strFdlTemplateFile, strError)
    tLog.error(strMsg)
    error(strMsg)
  end

  -- Create a new FDL instance.
  local tFDL = require 'fdl'(tLog)

  -- Get any data after the FDL.
  local sizBinaryFdlMaxInBytes = tFDL.sizBinaryFdlMaxInBytes or 1024
  local strExtraData = string.sub(strFdlTemplate, sizBinaryFdlMaxInBytes+1)

  -- Parse the binary FDL into a structure.
  local tFDLContents = tFDL:bin2fdl(strFdlTemplate)
  if tFDLContents==nil then
    error('Failed to parse the FDL.')
  end

  return tFDLContents, strExtraData
end



function TestClassFDLBase:readTemplateFromWFP(
  tPlugin,
  strWfpFile,
  strWfpConditions,
  strWfp_Bus,
  ulWFP_FDL_Unit,
  ulWFP_FDL_ChipSelect,
  ulWFP_FDL_Offset
)
  local tLog = self.tLog
  local pl = self.pl

  local astrWfpConditions = pl.stringx.split(strWfpConditions, ',')
  local atWfpConditions = {}
  for _, strCondition in ipairs(astrWfpConditions) do
    local strKey, strValue = string.match(strCondition, '([^=]+)=(.*)')
    if strKey==nil then
      tLog.error('Invalid condition: "%s".', strCondition)
      error('Invalid condition.')
    elseif atWfpConditions[strKey]~=nil then
      tLog.error('Redefinition of condition "%s".', strKey)
      error('Redefinition of condition.')
    else
      atWfpConditions[strKey] = strValue
    end
  end

  local tWFP_FDL_Bus
  if strWfp_Bus~=nil then
    tWFP_FDL_Bus = self.atName2Bus[strWfp_Bus]
    if tWFP_FDL_Bus==nil then
      local strMsg = string.format('Error in parameters: unknown bus "%s" found in control file.', strWfp_Bus)
      tLog.error('%s', strMsg)
      error(strMsg)
    end
  end

  local tAsicTyp = tPlugin:GetChiptyp()
  local atDefaults = self.atDefaultFDLPosition[tAsicTyp]
  if atDefaults~=nil then
    if tWFP_FDL_Bus==nil then
      tWFP_FDL_Bus = atDefaults.bus
    end
    if ulWFP_FDL_Unit==nil then
      ulWFP_FDL_Unit = atDefaults.unit
    end
    if ulWFP_FDL_ChipSelect==nil then
      ulWFP_FDL_ChipSelect = atDefaults.chipselect
    end
    if ulWFP_FDL_Offset==nil then
      ulWFP_FDL_Offset = atDefaults.offset
    end
  end

  local astrErrors = {}
  if tWFP_FDL_Bus==nil then
    table.insert(astrErrors, 'bus')
  end
  if ulWFP_FDL_Unit==nil then
    table.insert(astrErrors, 'unit')
  end
  if ulWFP_FDL_ChipSelect==nil then
    table.insert(astrErrors, 'chipselect')
  end
  if ulWFP_FDL_Offset==nil then
    table.insert(astrErrors, 'offset')
  end
  if #astrErrors~=0 then
    local strMsg = string.format(
      'The following parameter are missing and no defaults found for chiptype %d: %s',
      tAsicTyp,
      table.concat(astrErrors, ', ')
    )
    tLog.error('%s', strMsg)
    error(strMsg)
  end

  -- Does the file exist?
  if pl.path.exists(strWfpFile)~=strWfpFile then
    local strMsg = string.format('The WFP file "%s" does not exist.', strWfpFile)
    tLog.error('%s', strMsg)
    error(strMsg)
  end

  local wfp_control = require 'wfp_control'
  local tWfpControl = wfp_control(self.tLogWriter)

  -- Read the control file from the WFP archive.
  tLog.debug('Using WFP archive "%s".', strWfpFile)
  local tResult = tWfpControl:open(strWfpFile)
  if tResult==nil then
    local strMsg = string.format('Failed to open the WFP file "%s".', strWfpFile)
    tLog.error('%s', strMsg)
    error(strMsg)
  end

  -- Does the WFP have an entry for the chip?
  local tTarget = tWfpControl:getTarget(tAsicTyp)
  if tTarget==nil then
    local strMsg = string.format('The chip type %d is not supported by this WFP.', tAsicTyp)
    tLog.error('%s', strMsg)
    error(strMsg)
  end

  -- Loop over all flashes.
  local strFdlTemplate
  for _, tTargetFlash in ipairs(tTarget.atFlashes) do
    local strBusName = tTargetFlash.strBus
    local tBus = self.atName2Bus[strBusName]
    if tBus==nil then
      local strMsg = string.format(
        'Error in WFP file "%s": unknown bus "%s" found in control file.',
        strWfpFile,
        strBusName
      )
      tLog.error('%s', strMsg)
      error(strMsg)
    end

    local ulUnit = tTargetFlash.ulUnit
    local ulChipSelect = tTargetFlash.ulChipSelect

    if tBus~=tWFP_FDL_Bus or ulUnit~=ulWFP_FDL_Unit or ulChipSelect~=ulWFP_FDL_ChipSelect then
      tLog.debug('Ignoring entries for bus: %s, unit: %d, chip select: %d', strBusName, ulUnit, ulChipSelect)
    else
      for _, tData in ipairs(tTargetFlash.atData) do
        -- Is this a flash command?
        if tData.strFile~=nil then
          local strFile = pl.path.basename(tData.strFile)
          local ulOffset = tData.ulOffset
          local strCondition = tData.strCondition
          tLog.info('Found file "%s" with offset 0x%08x and condition "%s".', strFile, ulOffset, strCondition)

          if ulOffset~=ulWFP_FDL_Offset then
            tLog.debug('Ignoring entry for offset 0x%08x.', ulOffset)
          else
            if tWfpControl:matchCondition(atWfpConditions, strCondition)~=true then
              tLog.info('Not processing file %s : prevented by condition.', strFile)
            else
              -- Loading the file data from the archive.
              strFdlTemplate = tWfpControl:getData(strFile)
              if strFdlTemplate==nil then
                local strMsg = string.format(
                  'Error in WFP "%s": failed to extract the data for file "%s".',
                  strWfpFile,
                  strFile
                )
                tLog.error(strMsg)
                error(strMsg)
              end
              break
            end
          end
        end
      end

      if strFdlTemplate~=nil then
        break
      end
    end
  end
  if strFdlTemplate==nil then
    local strMsg = string.format(
      'No FDL entry found in WFP "%s" with bus: %s, unit: %d, chip select: %d, offset: %d and conditions "%s".',
      strWfpFile,
      tWFP_FDL_Bus,
      ulWFP_FDL_Unit,
      ulWFP_FDL_ChipSelect,
      ulWFP_FDL_Offset,
      strWfpConditions
    )
    tLog.error('%s', strMsg)
    error(strMsg)
  end

  -- Create a new FDL instance.
  local tFDL = require 'fdl'(tLog)

  -- Get any data after the FDL.
  local sizBinaryFdlMaxInBytes = tFDL.sizBinaryFdlMaxInBytes or 1024
  local strExtraData = string.sub(strFdlTemplate, sizBinaryFdlMaxInBytes+1)

  -- Parse the binary FDL into a structure.
  local tFDLContents = tFDL:bin2fdl(strFdlTemplate)
  if tFDLContents==nil then
    error('Failed to parse the FDL.')
  end

  return tFDLContents, strExtraData
end


function TestClassFDLBase:setProductionDate(tPatches)
  local tLog = self.tLog

  -- Get the production date.
  local date = require 'date'
  -- Get the local time.
  local tDateNow = date(false)
  -- Get the lower 2 digits of the year.
  local ulYear = tDateNow:getisoyear() % 100
  -- Get the week number.
  local ulWeek = tDateNow:getisoweeknumber()
  local usProductionDate = ulYear*256 + ulWeek

  -- Patch the production date.
  tPatches.tBasicDeviceData.usProductionDate = usProductionDate
  tLog.debug('Add the production date 0x%04x to the FDL patches.', usProductionDate)
end



function TestClassFDLBase:applyPatchData(tFDLContents, tPatches)
  local tLog = self.tLog

  -- Create a basic device data structure in the patch data if not present yet.
  if tPatches.tBasicDeviceData==nil then
    tLog.debug('The patch data does not have a basic device data structure. Create one now.')
    tPatches.tBasicDeviceData = {}
  end

  -- Create a new FDL instance.
  local tFDL = require 'fdl'(tLog)

  -- Apply all patches.
  tFDL:patchFdl(tFDLContents, tPatches)
end


return TestClassFDLBase
