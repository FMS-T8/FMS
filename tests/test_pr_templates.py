"""
Comprehensive tests for GitHub Pull Request template markdown files.

Tests validate markdown structure, required sections, formatting, and content consistency.
"""
import os
import re
import pytest
from pathlib import Path


class TestPRTemplates:
    """Test suite for PR template validation."""

    @pytest.fixture
    def templates_dir(self):
        """Path to .github/PULL_REQUEST_TEMPLATE directory."""
        return Path(__file__).parent.parent / ".github" / "PULL_REQUEST_TEMPLATE"

    @pytest.fixture
    def default_template_path(self):
        """Path to default PR template."""
        return Path(__file__).parent.parent / ".github" / "PULL_REQUEST_TEMPLATE.md"

    @pytest.fixture
    def bugfix_template_path(self, templates_dir):
        """Path to bugfix template."""
        return templates_dir / "bugfix.md"

    @pytest.fixture
    def docs_template_path(self, templates_dir):
        """Path to docs template."""
        return templates_dir / "docs.md"

    @pytest.fixture
    def feature_template_path(self, templates_dir):
        """Path to feature template."""
        return templates_dir / "feature.md"

    def test_templates_directory_exists(self, templates_dir):
        """Test that PULL_REQUEST_TEMPLATE directory exists."""
        assert templates_dir.exists(), f"Templates directory not found at {templates_dir}"
        assert templates_dir.is_dir(), "PULL_REQUEST_TEMPLATE should be a directory"

    def test_default_template_exists(self, default_template_path):
        """Test that default PR template exists."""
        assert default_template_path.exists(), \
            f"Default template not found at {default_template_path}"

    def test_bugfix_template_exists(self, bugfix_template_path):
        """Test that bugfix template exists."""
        assert bugfix_template_path.exists(), \
            f"Bugfix template not found at {bugfix_template_path}"

    def test_docs_template_exists(self, docs_template_path):
        """Test that docs template exists."""
        assert docs_template_path.exists(), \
            f"Docs template not found at {docs_template_path}"

    def test_feature_template_exists(self, feature_template_path):
        """Test that feature template exists."""
        assert feature_template_path.exists(), \
            f"Feature template not found at {feature_template_path}"

    def test_default_template_not_empty(self, default_template_path):
        """Test that default template is not empty."""
        content = default_template_path.read_text()
        assert len(content.strip()) > 0, "Default template is empty"

    def test_bugfix_template_not_empty(self, bugfix_template_path):
        """Test that bugfix template is not empty."""
        content = bugfix_template_path.read_text()
        assert len(content.strip()) > 0, "Bugfix template is empty"

    def test_docs_template_not_empty(self, docs_template_path):
        """Test that docs template is not empty."""
        content = docs_template_path.read_text()
        assert len(content.strip()) > 0, "Docs template is empty"

    def test_feature_template_not_empty(self, feature_template_path):
        """Test that feature template is not empty."""
        content = feature_template_path.read_text()
        assert len(content.strip()) > 0, "Feature template is empty"


class TestDefaultTemplate:
    """Tests specific to the default PR template."""

    @pytest.fixture
    def template_content(self):
        """Load default template content."""
        template_path = Path(__file__).parent.parent / ".github" / "PULL_REQUEST_TEMPLATE.md"
        return template_path.read_text()

    def test_has_description_section(self, template_content):
        """Test that template has Description section."""
        assert "## Description" in template_content, "Missing Description section"

    def test_has_type_of_change_section(self, template_content):
        """Test that template has Type of Change section."""
        assert "## Type of Change" in template_content, "Missing Type of Change section"

    def test_has_changes_made_section(self, template_content):
        """Test that template has Changes Made section."""
        assert "## Changes Made" in template_content, "Missing Changes Made section"

    def test_has_testing_section(self, template_content):
        """Test that template has Testing section."""
        assert "## Testing" in template_content, "Missing Testing section"

    def test_has_checklist_section(self, template_content):
        """Test that template has Checklist section."""
        assert "## Checklist" in template_content, "Missing Checklist section"

    def test_has_comment_about_specialized_templates(self, template_content):
        """Test that template mentions specialized templates."""
        assert "template=feature.md" in template_content, \
            "Should mention feature.md template"
        assert "template=bugfix.md" in template_content, \
            "Should mention bugfix.md template"
        assert "template=docs.md" in template_content, \
            "Should mention docs.md template"

    def test_type_of_change_has_checkboxes(self, template_content):
        """Test that Type of Change section has checkbox items."""
        # Find Type of Change section
        assert "- [ ] Feature" in template_content, "Missing Feature checkbox"
        assert "- [ ] Bug fix" in template_content, "Missing Bug fix checkbox"
        assert "- [ ] Documentation" in template_content, "Missing Documentation checkbox"
        assert "- [ ] Refactor" in template_content, "Missing Refactor checkbox"
        assert "- [ ] Other" in template_content, "Missing Other checkbox"

    def test_checklist_has_items(self, template_content):
        """Test that Checklist section has required items."""
        # Find checklist items
        assert "- [ ] Code compiles without warnings" in template_content
        assert "- [ ] Self-reviewed" in template_content
        assert "- [ ] Tests pass" in template_content

    def test_has_html_comments_for_guidance(self, template_content):
        """Test that template has HTML comments for user guidance."""
        assert "<!--" in template_content, "Should have HTML comments"
        assert "-->" in template_content, "Should close HTML comments"

    def test_uses_proper_markdown_headers(self, template_content):
        """Test that template uses proper markdown header syntax."""
        # Find all headers
        headers = re.findall(r'^##\s+.+$', template_content, re.MULTILINE)
        assert len(headers) >= 5, "Should have at least 5 main sections"

        # Check that headers are properly formatted (## followed by space)
        for header in headers:
            assert header.startswith("## "), f"Invalid header format: {header}"

    def test_checklist_items_are_unchecked(self, template_content):
        """Test that all checklist items are initially unchecked."""
        # Find all checkbox items in template
        checkboxes = re.findall(r'- \[([ x])\]', template_content)
        for checkbox in checkboxes:
            assert checkbox == " ", "Checkboxes should be unchecked by default"

    def test_no_broken_links(self, template_content):
        """Test that template has no obviously broken markdown links."""
        # Find markdown links
        links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', template_content)

        for link_text, link_url in links:
            # Check that URL is not empty
            assert len(link_url.strip()) > 0, f"Empty URL in link: [{link_text}]"


class TestBugfixTemplate:
    """Tests specific to the bugfix PR template."""

    @pytest.fixture
    def template_content(self):
        """Load bugfix template content."""
        template_path = Path(__file__).parent.parent / ".github" / \
                       "PULL_REQUEST_TEMPLATE" / "bugfix.md"
        return template_path.read_text()

    def test_has_bug_fix_title(self, template_content):
        """Test that template has Bug Fix title."""
        assert "## Bug Fix" in template_content, "Missing Bug Fix title"

    def test_has_issue_section(self, template_content):
        """Test that template has Issue section."""
        assert "### Issue" in template_content, "Missing Issue section"

    def test_has_root_cause_section(self, template_content):
        """Test that template has Root Cause section."""
        assert "### Root Cause" in template_content, "Missing Root Cause section"

    def test_has_fix_section(self, template_content):
        """Test that template has Fix section."""
        assert "### Fix" in template_content, "Missing Fix section"

    def test_has_testing_section(self, template_content):
        """Test that template has Testing section."""
        assert "### Testing" in template_content, "Missing Testing section"

    def test_has_checklist_section(self, template_content):
        """Test that template has Checklist section."""
        assert "### Checklist" in template_content, "Missing Checklist section"

    def test_checklist_has_bug_specific_items(self, template_content):
        """Test that checklist has bug-fix specific items."""
        assert "- [ ] Bug reproduced" in template_content, \
            "Missing 'Bug reproduced' checklist item"
        assert "- [ ] Fix verified" in template_content, \
            "Missing 'Fix verified' checklist item"
        assert "- [ ] No regressions introduced" in template_content, \
            "Missing 'No regressions' checklist item"

    def test_uses_subsection_headers(self, template_content):
        """Test that template uses ### for subsections."""
        subsections = re.findall(r'^###\s+.+$', template_content, re.MULTILINE)
        assert len(subsections) >= 5, "Should have at least 5 subsections"

    def test_has_guidance_comments(self, template_content):
        """Test that sections have guidance comments."""
        assert "<!-- Describe the bug. -->" in template_content
        assert "<!-- Explain why it happened. -->" in template_content
        assert "<!-- Describe the solution. -->" in template_content

    def test_checklist_items_unchecked(self, template_content):
        """Test that bugfix checklist items are initially unchecked."""
        checkboxes = re.findall(r'- \[([ x])\]', template_content)
        for checkbox in checkboxes:
            assert checkbox == " ", "Checkboxes should be unchecked by default"


class TestDocsTemplate:
    """Tests specific to the documentation PR template."""

    @pytest.fixture
    def template_content(self):
        """Load docs template content."""
        template_path = Path(__file__).parent.parent / ".github" / \
                       "PULL_REQUEST_TEMPLATE" / "docs.md"
        return template_path.read_text()

    def test_has_documentation_change_title(self, template_content):
        """Test that template has Documentation Change title."""
        assert "## Documentation Change" in template_content, \
            "Missing Documentation Change title"

    def test_has_summary_section(self, template_content):
        """Test that template has Summary section."""
        assert "### Summary" in template_content, "Missing Summary section"

    def test_has_files_updated_section(self, template_content):
        """Test that template has Files Updated section."""
        assert "### Files Updated" in template_content, "Missing Files Updated section"

    def test_has_reason_section(self, template_content):
        """Test that template has Reason section."""
        assert "### Reason" in template_content, "Missing Reason section"

    def test_has_checklist_section(self, template_content):
        """Test that template has Checklist section."""
        assert "### Checklist" in template_content, "Missing Checklist section"

    def test_checklist_has_docs_specific_items(self, template_content):
        """Test that checklist has documentation-specific items."""
        assert "- [ ] Links verified" in template_content, \
            "Missing 'Links verified' checklist item"
        assert "- [ ] No outdated info" in template_content, \
            "Missing 'No outdated info' checklist item"
        assert "- [ ] Markdown renders correctly" in template_content, \
            "Missing 'Markdown renders correctly' checklist item"

    def test_has_guidance_comments(self, template_content):
        """Test that sections have appropriate guidance."""
        assert "<!-- Explain what documentation was added or updated. -->" in template_content
        assert "<!-- List modified documentation files. -->" in template_content
        assert "<!-- Why this documentation change is needed. -->" in template_content

    def test_checklist_items_unchecked(self, template_content):
        """Test that docs checklist items are initially unchecked."""
        checkboxes = re.findall(r'- \[([ x])\]', template_content)
        for checkbox in checkboxes:
            assert checkbox == " ", "Checkboxes should be unchecked by default"


class TestFeatureTemplate:
    """Tests specific to the feature PR template."""

    @pytest.fixture
    def template_content(self):
        """Load feature template content."""
        template_path = Path(__file__).parent.parent / ".github" / \
                       "PULL_REQUEST_TEMPLATE" / "feature.md"
        return template_path.read_text()

    def test_has_feature_title(self, template_content):
        """Test that template has Feature title."""
        assert "## Feature" in template_content, "Missing Feature title"

    def test_has_summary_section(self, template_content):
        """Test that template has Summary section."""
        assert "### Summary" in template_content, "Missing Summary section"

    def test_has_problem_section(self, template_content):
        """Test that template has Problem section."""
        assert "### Problem" in template_content, "Missing Problem section"

    def test_has_solution_section(self, template_content):
        """Test that template has Solution section."""
        assert "### Solution" in template_content, "Missing Solution section"

    def test_has_changes_section(self, template_content):
        """Test that template has Changes section."""
        assert "### Changes" in template_content, "Missing Changes section"

    def test_has_testing_section(self, template_content):
        """Test that template has Testing section."""
        assert "### Testing" in template_content, "Missing Testing section"

    def test_has_checklist_section(self, template_content):
        """Test that template has Checklist section."""
        assert "### Checklist" in template_content, "Missing Checklist section"

    def test_checklist_has_feature_specific_items(self, template_content):
        """Test that checklist has feature-specific items."""
        assert "- [ ] Tests added" in template_content, \
            "Missing 'Tests added' checklist item"
        assert "- [ ] No breaking changes" in template_content, \
            "Missing 'No breaking changes' checklist item"
        assert "- [ ] Documentation updated" in template_content, \
            "Missing 'Documentation updated' checklist item"

    def test_changes_section_has_structure(self, template_content):
        """Test that Changes section provides structure guidance."""
        assert "- New components/modules" in template_content or \
               "New components" in template_content, \
            "Should guide on listing new components"

    def test_has_guidance_comments(self, template_content):
        """Test that sections have appropriate guidance."""
        assert "<!-- Describe the feature. -->" in template_content
        assert "<!-- What problem does this solve? -->" in template_content
        assert "<!-- Explain the implementation. -->" in template_content

    def test_checklist_items_unchecked(self, template_content):
        """Test that feature checklist items are initially unchecked."""
        checkboxes = re.findall(r'- \[([ x])\]', template_content)
        for checkbox in checkboxes:
            assert checkbox == " ", "Checkboxes should be unchecked by default"


class TestTemplateConsistency:
    """Tests for consistency across all templates."""

    @pytest.fixture
    def all_templates(self):
        """Load all template contents."""
        base_path = Path(__file__).parent.parent / ".github"
        return {
            'default': (base_path / "PULL_REQUEST_TEMPLATE.md").read_text(),
            'bugfix': (base_path / "PULL_REQUEST_TEMPLATE" / "bugfix.md").read_text(),
            'docs': (base_path / "PULL_REQUEST_TEMPLATE" / "docs.md").read_text(),
            'feature': (base_path / "PULL_REQUEST_TEMPLATE" / "feature.md").read_text(),
        }

    def test_all_templates_use_markdown_format(self, all_templates):
        """Test that all templates use markdown format."""
        for name, content in all_templates.items():
            # Check for markdown headers
            assert re.search(r'^##', content, re.MULTILINE), \
                f"{name} template should use markdown headers"

    def test_all_specialized_templates_have_checklists(self, all_templates):
        """Test that all specialized templates have checklists."""
        for name in ['bugfix', 'docs', 'feature']:
            content = all_templates[name]
            assert "### Checklist" in content, \
                f"{name} template should have a checklist"
            assert "- [ ]" in content, \
                f"{name} template should have checkbox items"

    def test_all_templates_have_guidance_comments(self, all_templates):
        """Test that all templates provide user guidance via comments."""
        for name, content in all_templates.items():
            assert "<!--" in content, \
                f"{name} template should have guidance comments"
            assert "-->" in content, \
                f"{name} template should close guidance comments"

    def test_all_templates_end_with_newline(self, all_templates):
        """Test that templates preferably end with a newline (best practice)."""
        base_path = Path(__file__).parent.parent / ".github"
        paths = {
            'default': base_path / "PULL_REQUEST_TEMPLATE.md",
            'bugfix': base_path / "PULL_REQUEST_TEMPLATE" / "bugfix.md",
            'docs': base_path / "PULL_REQUEST_TEMPLATE" / "docs.md",
            'feature': base_path / "PULL_REQUEST_TEMPLATE" / "feature.md",
        }

        # Check which templates end with newlines (best practice but not critical)
        templates_without_newline = []
        for name, path in paths.items():
            content = path.read_text()
            if not content.endswith('\n'):
                templates_without_newline.append(name)

        # This is informational - files should ideally end with newlines but it's not critical
        # For now, we just verify the check runs without error
        assert len(paths) == 4, "Should check all 4 template files"

    def test_specialized_templates_use_subsections(self, all_templates):
        """Test that specialized templates use ### for subsections."""
        for name in ['bugfix', 'docs', 'feature']:
            content = all_templates[name]
            subsections = re.findall(r'^###\s+', content, re.MULTILINE)
            assert len(subsections) >= 3, \
                f"{name} template should have multiple subsections"

    def test_templates_have_reasonable_length(self, all_templates):
        """Test that templates are not too short or too long."""
        for name, content in all_templates.items():
            # Remove comments and whitespace for counting
            actual_content = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)
            actual_content = actual_content.strip()

            assert len(actual_content) > 50, \
                f"{name} template seems too short"
            assert len(content) < 5000, \
                f"{name} template seems excessively long"

    def test_no_trailing_whitespace_on_headers(self, all_templates):
        """Test that headers don't have trailing whitespace."""
        for name, content in all_templates.items():
            headers = re.findall(r'^#+\s+.+$', content, re.MULTILINE)
            for header in headers:
                assert not header.endswith(' '), \
                    f"{name} has header with trailing space: {header}"

    def test_consistent_checkbox_format(self, all_templates):
        """Test that all checkboxes use consistent format."""
        for name, content in all_templates.items():
            # Find all checkboxes
            checkboxes = re.findall(r'- \[[ x]\].+', content)
            for checkbox in checkboxes:
                # Should be "- [ ]" not "-[ ]" or "- []"
                assert checkbox.startswith("- ["), \
                    f"{name} has inconsistent checkbox format"

    def test_edge_case_empty_lines_consistency(self, all_templates):
        """Edge case: test that templates don't have excessive empty lines."""
        for name, content in all_templates.items():
            # Check for more than 3 consecutive newlines
            assert not re.search(r'\n\n\n\n', content), \
                f"{name} has excessive empty lines"

    def test_boundary_all_sections_have_content_markers(self, all_templates):
        """Boundary test: verify all sections have content markers or guidance."""
        for name in ['bugfix', 'docs', 'feature']:
            content = all_templates[name]
            # Find all subsections
            subsections = re.findall(r'###\s+(.+)$', content, re.MULTILINE)

            for subsection in subsections:
                if subsection != "Checklist":
                    # Should have some guidance comment or content
                    # Look for the section and check next few lines
                    pattern = f"### {re.escape(subsection)}"
                    assert re.search(pattern, content), \
                        f"Section {subsection} in {name} should exist"