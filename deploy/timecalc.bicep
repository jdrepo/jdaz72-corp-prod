@description('Optional. Current UTC date and time in Universal sortable date/time pattern')
param nowUtc string = utcNow('u')

@description('Optional. Deployment start time' )
param DeploymentStartTime string = '01:00'

var todayDate = substring((nowUtc), 0, 10)
var nowUtcTicks = dateTimeToEpoch(nowUtc)
var offsetSeconds = 300 // time delay of 5min to allow for deployment delays
var scheduleStart = dateTimeAdd('${todayDate}T${DeploymentStartTime}', dateTimeToEpoch('${todayDate}T${DeploymentStartTime}') > nowUtcTicks + offsetSeconds  ? 'P0D' : 'P1D')


output scheduleStart string = scheduleStart
output scheduleStartMaintenance string =  '${substring(scheduleStart, 0, 10)} ${DeploymentStartTime}'

