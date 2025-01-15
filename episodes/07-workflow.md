---
title: Workflow
teaching: 20
exercises: 20
---

::::::::::::::::::::::::::::::::::::::: objectives

- Create a Nextflow workflow joining multiple processes.
- Understand how to to connect processes via their inputs and outputs within a workflow.

::::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::: questions

- How do I connect channels and processes to create a workflow?
- How do I invoke a process inside a workflow?

::::::::::::::::::::::::::::::::::::::::::::::::::

## Workflow

Our previous episodes have shown us how to parameterise workflows using `params`, move data around a workflow using `channels` and define individual tasks using `processes`. In this episode we will cover how connect multiple processes to create a workflow.

## Workflow definition

We can connect processes to create our pipeline inside a `workflow` scope.
The  workflow scope starts with the keyword `workflow`, followed by an optional name and finally the workflow body delimited by curly brackets `{}`.

::::::::::::::::::::::::::::::::::::::::  callout

## Implicit workflow

In contrast to processes, the workflow definition in Nextflow does not require a name. In Nextflow, if you don't give a name to a workflow, it's considered the main/implicit starting point of your workflow program.

A named workflow is a `subworkflow` that can be invoked from other workflows, subworkflows are not covered in this lesson, more information can be found in the official documentation [here](https://www.nextflow.io/docs/latest/workflow.html).

::::::::::::::::::::::::::::::::::::::::::::::::::

### Invoking processes with a workflow

As seen previously, a `process` is invoked as a function in the `workflow` scope, passing the expected input channels as arguments as it if were.

```
 <process_name>(<input_ch1>,<input_ch2>,...)
```

To combined multiple processes invoke them in the order they would appear in a workflow. When invoking a process with multiple inputs, provide them in the same order in which they are declared in the `input` block of the process.

For example:

```groovy 
//workflow_01.nf



 process calculate_statistic {
    publishDir "${params.output_dir}/stats", mode: "copy"
    tag "${data.getSimpleName()}-${which_stat}"

    input:
    tuple val(which_stat), path(data)

    output:
    tuple val(which_stat), path("*_${which_stat}.txt")

    script:
    
    fn = data.name

    """
    calc_stats.py --${which_stat} ${data} > ${fn}_${which_stat}.txt
    """

}


process collate_statistic {
    publishDir "${params.output_dir}/collated", mode: "copy"
    tag "${which_stat}"

    input:
    tuple val(which_stat), path(data)

    output:
    tuple val(which_stat), path("*.collated.txt")

    script:
    
    """
    ls ${data} | cut -f 1 -d . | tr "\\n" "\\t" | sed "s/\$/\\n/" > ${which_stat}.collated.txt
    paste ${data} >> ${which_stat}.collated.txt
    """


}

workflow {
    which_stat_ch = Channel.of(params.which_stat.split(","))
        .filter { it == "max" || it == "min" || it == "mean" }
    
    input_ch = Channel.fromPath(params.input_data)
    
    calculations_ch = which_stat_ch.combine(input_ch)
    
    stats_ch = calculate_statistic(calculations_ch)
    
    collate_input_ch = stats_ch.groupTuple(by: 0)
    
    collated_ch = collate_statistic(collate_input_ch)
}

```

### Process outputs

In the previous example we assigned the process output to a Nextflow variable `stats_ch`.

A process output can also be accessed directly using the `out` attribute for the respective `process object`.

For example:

```groovy 
[..truncated..]

workflow {
  which_stat_ch = Channel.of(params.which_stat.split(","))
        .filter { it == "max" || it == "min" || it == "mean" }
    
    input_ch = Channel.fromPath(params.input_data)
    
    calculations_ch = which_stat_ch.combine(input_ch)
    
    calculate_statistic(calculations_ch)
    
    // process output accessed using the `out` attribute of the process object
    collated_ch = collate_statistic(calculate_statistic.out.groupTuple(by: 0))
}

```

When a process defines two or more output channels, each of them can be accessed using the list element operator e.g. `out[0]`, `out[1]`, or using named outputs.

### Process named output

It can be useful to name the output of a process, especially if there are multiple outputs.

The process `output` definition allows the use of the `emit:` option to define a named identifier that can be used to reference the channel in the external scope.

For example in the script below we name the output from the `calculate_statistic` process as `stat` using the `emit:` option. We can then reference the output as
`calculate_statistic.out.stat` in the workflow scope.

```groovy 
//workflow_02.nf


 process calculate_statistic {
    publishDir "${params.output_dir}/stats", mode: "copy"
    tag "${data.getSimpleName()}-${which_stat}"

    input:
    tuple val(which_stat), path(data)

    output:
    tuple val(which_stat), path("*_${which_stat}.txt"), emit: "stat"

    script:
    
    fn = data.name

    """
    calc_stats.py --${which_stat} ${data} > ${fn}_${which_stat}.txt
    """

}


process collate_statistic {
    publishDir "${params.output_dir}/collated", mode: "copy"
    tag "${which_stat}"

    input:
    tuple val(which_stat), path(data)

    output:
    tuple val(which_stat), path("*.collated.txt")

    script:
    
    """
    ls ${data} | cut -f 1 -d . | tr "\\n" "\\t" | sed "s/\$/\\n/" > ${which_stat}.collated.txt
    paste ${data} >> ${which_stat}.collated.txt
    """


}

workflow {
    which_stat_ch = Channel.of(params.which_stat.split(","))
        .filter { it == "max" || it == "min" || it == "mean" }
    
    input_ch = Channel.fromPath(params.input_data)
    
    calculations_ch = which_stat_ch.combine(input_ch)
    
    stats_ch = calculate_statistic(calculations_ch).stat
    
    collate_input_ch = stats_ch.groupTuple(by: 0)
    
    collated_ch = collate_statistic(collate_input_ch)
}

```

### Accessing script parameters

A workflow component can access any variable and parameter defined in the outer scope:

For example:

```groovy 
//workflow_03.nf
[..truncated..]

params.which_stat = 'mean'

workflow {
    which_stat_ch = Channel.of(params.which_stat.split(","))
        .filter { it == "max" || it == "min" || it == "mean" }
    
    input_ch = Channel.fromPath(params.input_data)
    
    calculations_ch = which_stat_ch.combine(input_ch)
    
    stats_ch = calculate_statistic(calculations_ch).stat
    
    collate_input_ch = stats_ch.groupTuple(by: 0)
    
    collated_ch = collate_statistic(collate_input_ch)
}

```

In this example `params.which_stat`, defined outside the workflow scope, can be accessed inside the `workflow` scope.

## Handling workflow metadata

It can be useful to communicate various metadata to the user, such as printing the pipeline parameters to the screen. This can be done using the the `log.info` command and a multiline string statement. The string method `.stripIndent()` command is used to remove the indentation on multi-line strings. `log.info` also saves the output to the log execution file `.nextflow.log`.

```groovy 
log.info """\
         which_stat: ${params.which_stat}
         """
         .stripIndent()
```

:::::::::::::::::::::::::::::::::::::::  challenge

## log.info

Modify the `workflow_04.nf` to print all the pipeline parameters by using a single `log.info` command and a multiline string statement.
See an example [here](https://github.com/nextflow-io/rnaseq-nf/blob/3b5b49f/main.nf#L41-L48).

```bash 
$ nextflow run workflow_04.nf --which_stat mean,max,min --input_data 'data/inflammation*.csv' --output_dir results
```

Look at the output log `.nextflow.log`.

:::::::::::::::  solution

## Solution

Below is an example log.info command printing all the pipeline parameters.

```groovy 
log.info """\
         I N F L A M M A T I O N - N F   P I P E L I N E
         ===============================================
         input_data : ${params.input_data}
         statistic  : ${params.which_stat}
         output_dir : ${params.output_dir}
         """
         .stripIndent()
```

```bash 
$ less .nextflow.log
```

:::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::::


## Handle completion event

This step shows how to execute an action when the pipeline completes the execution.

**Note:** that Nextflow processes define the execution of asynchronous tasks i.e. they are not executed one after another as they are written in the pipeline script as it would happen in a common imperative programming language.

We can use the `workflow.onComplete` event handler to print a confirmation message when the script completes.

```groovy
workflow.onComplete {
    log.info ( workflow.success ? "\nDone! Your results are in ${params.output_dir}/collated\n" : "Oops .. something went wrong" )
}
```

This code uses the ternary operator that is a shortcut expression that is equivalent to an if/else branch assigning some value to a variable.

```source
If expression is true? "set value to a" : "else set value to b"
```

Try to run it by using the following command:

```bash
$ nextflow run workflow_04.nf --which_stat mean,max,min --input_data 'data/inflammation*.csv' --output_dir results
```

```output
[..truncated..]
Done! Your results are in results/collated
```

## Metrics and reports

Nextflow is able to produce multiple reports and charts providing several runtime metrics and execution information.

- The `-with-report` option enables the creation of the workflow execution report.

- The `-with-trace` option enables the create of a tab separated file containing runtime information for each executed task, including: submission time, start time, completion time, cpu and memory used..

- The `-with-timeline` option enables the creation of the workflow timeline report showing how processes where executed along time. This may be useful to identify most time consuming tasks and bottlenecks. See an example at this [link](https://www.nextflow.io/docs/latest/tracing.html#timeline-report).

- The `-with-dag` option enables to rendering of the workflow execution direct acyclic graph representation.
  **Note:** this feature requires the installation of [Graphviz](https://graphviz.org/), an open source graph visualization software,  in your system.

More information can be found [here](https://www.nextflow.io/docs/latest/tracing.html).


:::::::::::::::::::::::::::::::::::::::: keypoints

- A Nextflow workflow is defined by invoking `processes` inside the `workflow` scope.
- A process is invoked like a function inside the `workflow` scope passing any required input parameters as arguments. e.g. `calculate_statistic(calculations_ch)`.
- Process outputs can be accessed using the `out` attribute for the respective `process` object or assigning the output to a Nextflow variable. 
- Multiple outputs from a single process can be accessed using the list syntax `[]` and it's index or by referencing the a named process output.
- Nextflow can combine tasks (processes) and manage data flows using channels into a single pipeline/workflow.
- A Workflow can be parameterised using `params`. The value of these parameters can be captured in a log file using  `log.info`
- Workflow steps are connected via their `inputs` and `outputs` using `Channels`.
- Intermediate pipeline results can be transformed using Channel `operators` such as `combine`.
- Nextflow can execute an action when the pipeline completes the execution using the `workflow.onComplete` event handler to print a confirmation message.
- Nextflow is able to produce multiple reports and charts providing several runtime metrics and execution information using the command line options `-with-report`, `-with-trace`, `-with-timeline` and produce a graph using `-with-dag`.



::::::::::::::::::::::::::::::::::::::::::::::::::


