package com.redhat.sonar.branchcomparison;

import org.sonar.api.Properties;
import org.sonar.api.Property;
import org.sonar.api.SonarPlugin;

import java.util.Arrays;
import java.util.List;


public final class BranchComparisonPlugin extends SonarPlugin {
  public List getExtensions() {
    return Arrays.asList();
  }
}
