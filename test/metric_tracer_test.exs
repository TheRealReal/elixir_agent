defmodule MetricTracerTest do
  use ExUnit.Case

  alias NewRelic.Harvest.Collector

  setup do
    TestHelper.restart_harvest_cycle(Collector.Metric.HarvestCycle)
    on_exit(fn -> TestHelper.pause_harvest_cycle(Collector.Metric.HarvestCycle) end)
  end

  defmodule MetricTraced do
    use NewRelic.Tracer

    @trace :fun
    def fun do
    end

    @trace :bar
    def foo do
    end

    @trace {:query, category: :external}
    def query do
    end

    @trace {:named_external, category: :external, metric_name: "domain.net"}
    def named_external do
    end

    @trace {:named_external_callback_arg,
            category: :external, metric_name: {__MODULE__, :report_name}}
    def named_external_callback_arg(path), do: path

    def report_name(path), do: "domain.net#{path}"

    @trace {:named_external_callback,
            category: :external, metric_name: {__MODULE__, :default_name}}
    def named_external_callback do
    end

    def default_name, do: "domain.net"

    @trace {:db_query, category: :datastore}
    def db_query do
    end

    @trace {:special, category: :external}
    def custom_name do
    end
  end

  test "External metrics" do
    MetricTraced.query()
    MetricTraced.query()
    MetricTraced.custom_name()
    MetricTraced.custom_name()

    metrics = TestHelper.gather_harvest(Collector.Metric.Harvester)

    assert TestHelper.find_metric(metrics, "External/MetricTracerTest.MetricTraced.query/all", 2)

    assert TestHelper.find_metric(
             metrics,
             "External/MetricTracerTest.MetricTraced.custom_name:special/all",
             2
           )
  end

  test "External metrics name" do
    MetricTraced.named_external()
    MetricTraced.named_external()

    metrics = TestHelper.gather_harvest(Collector.Metric.Harvester)

    assert TestHelper.find_metric(metrics, "External/domain.net/all", 2)
  end

  test "External metrics callback name with args" do
    MetricTraced.named_external_callback_arg("/query")
    MetricTraced.named_external_callback_arg("/query")

    metrics = TestHelper.gather_harvest(Collector.Metric.Harvester)

    assert TestHelper.find_metric(metrics, "External/domain.net/query/all", 2)
  end

  test "External metrics callback name without args" do
    MetricTraced.named_external_callback()
    MetricTraced.named_external_callback()

    metrics = TestHelper.gather_harvest(Collector.Metric.Harvester)

    assert TestHelper.find_metric(metrics, "External/domain.net/all", 2)
  end

  test "Datastore metrics" do
    MetricTraced.db_query()

    metrics = TestHelper.gather_harvest(Collector.Metric.Harvester)

    assert TestHelper.find_metric(
             metrics,
             "Datastore/statement/Database/MetricTracerTest.MetricTraced/db_query"
           )

    assert TestHelper.find_metric(metrics, "Datastore/Database/all")
  end
end
