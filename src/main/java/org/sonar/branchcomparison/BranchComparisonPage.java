import org.sonar.api.web.NavigationSection;
import org.sonar.api.web.Page;
import org.sonar.api.web.UserRole;
 
@NavigationSection(NavigationSection.CONFIGURATION)
@UserRole(UserRole.ADMIN)
public final class BranchComparisonPage implements Page {
  public String getId() {
    // URL of the controller
    return "/branch_comparison/index";
  }

  public String getTitle() {
    return "Branch Comparison";
  }
}
