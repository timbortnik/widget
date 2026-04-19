package org.bortnik.meteogram

/**
 * 7-day weekly meteogram widget. Shares all rendering logic with the
 * 48-hour widget; only the time range displayed and the X-axis labels differ.
 */
class MeteogramWeeklyWidgetProvider : MeteogramWidgetProvider() {
    override val layoutRes: Int = R.layout.meteogram_widget_weekly
    override val logTag: String = "MeteogramWeeklyWidget"
    override val labelStepHours: Int = 24
    override val labelFormat: TimeLabelFormat = TimeLabelFormat.WEEKDAY

    override fun chartView(weatherData: WeatherData): ChartView =
        weatherData.getWeeklyView()
}
