import QtQuick

// Multi-series rolling time-series plot.
//
// `series` is an array of { points: [{ time, value }], color: color }.
// Points older than `windowMs` are clipped; values are drawn on a shared
// scale, pinned to `fixedMaximum` when it is positive (100 for utilization)
// or auto-scaled to the visible peak otherwise.
//
// Adapted from Harshith292002/omarchy-system-monitor's Sparkline.qml (MIT),
// extended from one series to many so CPU, GPU and NPU share one time axis.
Canvas {
  id: root

  property var series: []
  property color gridColor: Qt.rgba(1, 1, 1, 0.10)
  property var gridLevels: [0.25, 0.5, 0.75]
  property real fixedMaximum: 100
  property int windowMs: 120000
  property real lineWidth: 1.5

  antialiasing: true
  onSeriesChanged: requestPaint()
  onGridColorChanged: requestPaint()
  onFixedMaximumChanged: requestPaint()
  onWindowMsChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function newestTime() {
    var newest = 0
    for (var s = 0; s < series.length; s++) {
      var points = series[s] ? series[s].points : null
      if (!points || points.length === 0) continue
      var last = Number(points[points.length - 1].time)
      if (isFinite(last) && last > newest) newest = last
    }
    return newest
  }

  function peakValue() {
    var peak = 0
    for (var s = 0; s < series.length; s++) {
      var points = series[s] ? series[s].points : null
      if (!points) continue
      for (var i = 0; i < points.length; i++) {
        var value = Number(points[i].value)
        if (isFinite(value) && value > peak) peak = value
      }
    }
    return peak
  }

  function drawGrid(ctx, axis, span) {
    ctx.strokeStyle = gridColor
    ctx.lineWidth = 1
    for (var i = 0; i < gridLevels.length; i++) {
      var level = Math.max(0, Math.min(1, Number(gridLevels[i])))
      var y = Math.round(axis - level * span) + 0.5
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(width, y)
      ctx.stroke()
    }
  }

  function drawSeries(ctx, points, oldest, maximum, axis, span, color) {
    if (!points || points.length < 2) return

    function pointX(point) {
      return Math.max(0, Math.min(width, (Number(point.time) - oldest) * width / windowMs))
    }
    function pointY(point) {
      var value = Number(point.value)
      if (!isFinite(value) || value < 0) value = 0
      return axis - Math.min(1, value / maximum) * span
    }

    ctx.beginPath()
    ctx.moveTo(pointX(points[0]), axis)
    for (var fillIndex = 0; fillIndex < points.length; fillIndex++)
      ctx.lineTo(pointX(points[fillIndex]), pointY(points[fillIndex]))
    ctx.lineTo(pointX(points[points.length - 1]), axis)
    ctx.closePath()
    ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.12)
    ctx.fill()

    ctx.beginPath()
    ctx.moveTo(pointX(points[0]), pointY(points[0]))
    for (var lineIndex = 1; lineIndex < points.length; lineIndex++)
      ctx.lineTo(pointX(points[lineIndex]), pointY(points[lineIndex]))
    ctx.strokeStyle = color
    ctx.lineWidth = lineWidth
    ctx.stroke()
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    if (width <= 0 || height <= 0) return

    var newest = newestTime()
    if (newest <= 0) return
    var oldest = newest - windowMs

    var maximum = fixedMaximum
    if (!(maximum > 0)) {
      maximum = peakValue() * 1.12
      if (!(maximum > 0)) maximum = 1
    }

    var axis = height - 1
    var span = height - 2
    drawGrid(ctx, axis, span)

    for (var s = 0; s < series.length; s++) {
      var item = series[s]
      if (!item) continue
      drawSeries(ctx, item.points, oldest, maximum, axis, span, item.color || gridColor)
    }
  }
}
