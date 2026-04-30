// Component 05: Log Analytics workspace + Action Group + staleness alert.

@description('Lowercase alphanumeric prefix')
@minLength(3)
@maxLength(8)
param prefix string

@description('Azure region')
param location string

@description('Workspace retention in days')
@minValue(30)
@maxValue(730)
param retentionDays int = 90

@description('Email address for staleness alerts (optional)')
param alertEmail string = ''

@description('Webhook URL for staleness alerts (optional)')
param alertWebhook string = ''

var unique4 = substring(uniqueString(resourceGroup().id), 0, 4)
var workspaceName = '${prefix}-la-${unique4}'

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  tags: {
    component: '05-log-analytics'
    project: 'awacs-secure-data-consolidation'
  }
}

// Action Group: at least one receiver required by ARM. We default to "no-op"
// when no email/webhook is provided, so the deploy succeeds; alert is created
// disabled and operator enables when ready.
var hasReceiver = !empty(alertEmail) || !empty(alertWebhook)

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (hasReceiver) {
  name: '${prefix}-ag-${unique4}'
  location: 'global'
  properties: {
    groupShortName: substring('${prefix}ag', 0, min(12, length('${prefix}ag')))
    enabled: true
    emailReceivers: empty(alertEmail) ? [] : [
      {
        name: 'OperatorEmail'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: empty(alertWebhook) ? [] : [
      {
        name: 'OperatorWebhook'
        serviceUri: alertWebhook
        useCommonAlertSchema: true
      }
    ]
  }
}

// Scheduled query alert: workstation hasn't pushed in >25h
resource stalenessAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (hasReceiver) {
  name: '${prefix}-staleness-alert'
  location: location
  dependsOn: [
    workspace
    actionGroup
  ]
  properties: {
    description: 'Fires when any workstation has not produced a PutBlob event in 25h.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'P2D'
    scopes: [
      workspace.id
    ]
    criteria: {
      allOf: [
        {
          query: '''
StorageBlobLogs
| where OperationName == "PutBlob"
| extend hostname = tostring(split(ObjectKey, "/")[0])
| summarize lastSeen = max(TimeGenerated) by hostname
| where lastSeen < ago(25h)
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

output workspaceId string = workspace.id
output workspaceCustomerId string = workspace.properties.customerId
output workspaceName string = workspace.name
