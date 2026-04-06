import 'package:flutter/material.dart';
import 'navigation_calibration.dart';
import 'id_verification.dart';
import 'reactor_alignment.dart';
import 'power_routing.dart';
import 'sample_analysis.dart';
import 'data_upload.dart';
import 'air_scrubber.dart';
import 'filter_replace.dart';
import 'signal_boost.dart';
import 'satellite_align.dart';

class _TaskMeta {
  final String displayName;
  final String zone;
  final Widget Function({required VoidCallback onComplete}) builder;
  const _TaskMeta(this.displayName, this.zone, this.builder);
}

final _registry = <String, _TaskMeta>{
  'navigation_calibration': _TaskMeta('Navigation Calibration', 'Command Bridge',
      ({required onComplete}) => NavigationCalibrationTask(onComplete: onComplete)),
  'id_verification': _TaskMeta('ID Verification', 'Command Bridge',
      ({required onComplete}) => IdVerificationTask(onComplete: onComplete)),
  'reactor_alignment': _TaskMeta('Reactor Alignment', 'Engineering Bay',
      ({required onComplete}) => ReactorAlignmentTask(onComplete: onComplete)),
  'power_routing': _TaskMeta('Power Routing', 'Engineering Bay',
      ({required onComplete}) => PowerRoutingTask(onComplete: onComplete)),
  'sample_analysis': _TaskMeta('Sample Analysis', 'Research Lab',
      ({required onComplete}) => SampleAnalysisTask(onComplete: onComplete)),
  'data_upload': _TaskMeta('Data Upload', 'Research Lab',
      ({required onComplete}) => DataUploadTask(onComplete: onComplete)),
  'air_scrubber': _TaskMeta('Air Scrubber Maintenance', 'Life Support',
      ({required onComplete}) => AirScrubberTask(onComplete: onComplete)),
  'filter_replace': _TaskMeta('Filter Replace', 'Life Support',
      ({required onComplete}) => FilterReplaceTask(onComplete: onComplete)),
  'signal_boost': _TaskMeta('Signal Boost', 'Comms Array',
      ({required onComplete}) => SignalBoostTask(onComplete: onComplete)),
  'satellite_align': _TaskMeta('Satellite Align', 'Comms Array',
      ({required onComplete}) => SatelliteAlignTask(onComplete: onComplete)),
};

class TaskRegistry {
  static Widget build(String taskId, {required VoidCallback onComplete}) {
    return _registry[taskId]?.builder(onComplete: onComplete) ??
      Center(child: Text('Unknown task: $taskId', style: const TextStyle(color: Colors.red)));
  }

  static String displayName(String taskId) => _registry[taskId]?.displayName ?? taskId;
  static String zone(String taskId) => _registry[taskId]?.zone ?? '';
  static List<String> allTaskIds() => _registry.keys.toList();
}
