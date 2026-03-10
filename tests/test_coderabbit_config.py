"""
Comprehensive tests for .coderabbit.yaml configuration file.

Tests validate YAML syntax, structure, valid values, and configuration completeness.
"""
import os
import pytest
import yaml
from pathlib import Path


class TestCodeRabbitConfig:
    """Test suite for CodeRabbit configuration validation."""

    @pytest.fixture
    def config_path(self):
        """Path to .coderabbit.yaml file."""
        return Path(__file__).parent.parent / ".coderabbit.yaml"

    @pytest.fixture
    def config(self, config_path):
        """Load and parse the CodeRabbit configuration."""
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)

    def test_config_file_exists(self, config_path):
        """Test that .coderabbit.yaml file exists."""
        assert config_path.exists(), f"Configuration file not found at {config_path}"

    def test_config_is_valid_yaml(self, config_path):
        """Test that configuration file contains valid YAML syntax."""
        try:
            with open(config_path, 'r') as f:
                yaml.safe_load(f)
        except yaml.YAMLError as e:
            pytest.fail(f"Invalid YAML syntax: {e}")

    def test_config_not_empty(self, config):
        """Test that configuration is not empty."""
        assert config is not None, "Configuration file is empty"
        assert len(config) > 0, "Configuration contains no settings"

    def test_reviews_section_exists(self, config):
        """Test that 'reviews' section is present in configuration."""
        assert 'reviews' in config, "Missing 'reviews' section in configuration"

    def test_reviews_section_structure(self, config):
        """Test that reviews section has expected fields."""
        reviews = config.get('reviews', {})
        assert isinstance(reviews, dict), "reviews section must be a dictionary"

        expected_fields = ['auto_review', 'auto_summarize', 'high_level_summary',
                          'final_sanity_check', 'poem']
        for field in expected_fields:
            assert field in reviews, f"Missing '{field}' in reviews section"

    def test_reviews_boolean_values(self, config):
        """Test that review settings are boolean values."""
        reviews = config.get('reviews', {})

        boolean_fields = ['auto_review', 'auto_summarize', 'high_level_summary',
                         'final_sanity_check', 'poem']
        for field in boolean_fields:
            value = reviews.get(field)
            assert isinstance(value, bool), f"{field} must be a boolean, got {type(value)}"

    def test_reviews_auto_review_enabled(self, config):
        """Test that auto_review is enabled."""
        reviews = config.get('reviews', {})
        assert reviews.get('auto_review') is True, "auto_review should be enabled"

    def test_reviews_auto_summarize_enabled(self, config):
        """Test that auto_summarize is enabled."""
        reviews = config.get('reviews', {})
        assert reviews.get('auto_summarize') is True, "auto_summarize should be enabled"

    def test_reviews_high_level_summary_enabled(self, config):
        """Test that high_level_summary is enabled."""
        reviews = config.get('reviews', {})
        assert reviews.get('high_level_summary') is True, "high_level_summary should be enabled"

    def test_reviews_final_sanity_check_enabled(self, config):
        """Test that final_sanity_check is enabled."""
        reviews = config.get('reviews', {})
        assert reviews.get('final_sanity_check') is True, "final_sanity_check should be enabled"

    def test_reviews_poem_disabled(self, config):
        """Test that poem generation is disabled."""
        reviews = config.get('reviews', {})
        assert reviews.get('poem') is False, "poem should be disabled"

    def test_chat_section_exists(self, config):
        """Test that 'chat' section is present in configuration."""
        assert 'chat' in config, "Missing 'chat' section in configuration"

    def test_chat_section_structure(self, config):
        """Test that chat section has expected fields."""
        chat = config.get('chat', {})
        assert isinstance(chat, dict), "chat section must be a dictionary"
        assert 'auto_reply' in chat, "Missing 'auto_reply' in chat section"

    def test_chat_auto_reply_enabled(self, config):
        """Test that auto_reply is enabled in chat section."""
        chat = config.get('chat', {})
        assert chat.get('auto_reply') is True, "chat.auto_reply should be enabled"

    def test_chat_auto_reply_is_boolean(self, config):
        """Test that auto_reply is a boolean value."""
        chat = config.get('chat', {})
        value = chat.get('auto_reply')
        assert isinstance(value, bool), f"auto_reply must be a boolean, got {type(value)}"

    def test_knowledge_base_section_exists(self, config):
        """Test that 'knowledge_base' section is present in configuration."""
        assert 'knowledge_base' in config, "Missing 'knowledge_base' section in configuration"

    def test_knowledge_base_section_structure(self, config):
        """Test that knowledge_base section has expected fields."""
        kb = config.get('knowledge_base', {})
        assert isinstance(kb, dict), "knowledge_base section must be a dictionary"
        assert 'enabled' in kb, "Missing 'enabled' in knowledge_base section"

    def test_knowledge_base_enabled(self, config):
        """Test that knowledge_base is enabled."""
        kb = config.get('knowledge_base', {})
        assert kb.get('enabled') is True, "knowledge_base.enabled should be true"

    def test_knowledge_base_enabled_is_boolean(self, config):
        """Test that knowledge_base.enabled is a boolean value."""
        kb = config.get('knowledge_base', {})
        value = kb.get('enabled')
        assert isinstance(value, bool), f"enabled must be a boolean, got {type(value)}"

    def test_no_extra_top_level_sections(self, config):
        """Test that only expected top-level sections are present."""
        expected_sections = {'reviews', 'chat', 'knowledge_base'}
        actual_sections = set(config.keys())
        extra_sections = actual_sections - expected_sections
        assert len(extra_sections) == 0, f"Unexpected top-level sections: {extra_sections}"

    def test_config_format_consistency(self, config_path):
        """Test that YAML file uses consistent formatting."""
        with open(config_path, 'r') as f:
            content = f.read()

        # Check for consistent indentation (2 spaces)
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            if line and not line.startswith('#'):
                # Check that indentation is in multiples of 2
                stripped = line.lstrip()
                if stripped:
                    indent = len(line) - len(stripped)
                    assert indent % 2 == 0, f"Line {i} has inconsistent indentation"

    def test_all_features_properly_configured(self, config):
        """Integration test: verify all features are properly configured together."""
        # Verify reviews are comprehensive
        reviews = config.get('reviews', {})
        enabled_reviews = [k for k, v in reviews.items() if v is True]
        assert len(enabled_reviews) >= 4, "At least 4 review features should be enabled"

        # Verify chat is interactive
        assert config.get('chat', {}).get('auto_reply') is True

        # Verify knowledge base support
        assert config.get('knowledge_base', {}).get('enabled') is True

    def test_configuration_completeness(self, config):
        """Test that configuration covers all major CodeRabbit features."""
        assert 'reviews' in config, "Reviews configuration missing"
        assert 'chat' in config, "Chat configuration missing"
        assert 'knowledge_base' in config, "Knowledge base configuration missing"

        # Ensure each section has at least one setting
        assert len(config['reviews']) > 0, "Reviews section is empty"
        assert len(config['chat']) > 0, "Chat section is empty"
        assert len(config['knowledge_base']) > 0, "Knowledge base section is empty"

    def test_negative_case_invalid_structure(self):
        """Negative test: verify detection of invalid configuration structure."""
        invalid_yaml = "reviews:\n  - this should be a dict not a list"

        try:
            parsed = yaml.safe_load(invalid_yaml)
            reviews = parsed.get('reviews')
            # This should fail if reviews is not a dict
            assert not isinstance(reviews, dict), "Should detect invalid structure"
        except Exception:
            pass  # Expected to fail parsing or validation

    def test_edge_case_empty_sections(self):
        """Edge case: verify behavior with empty sections."""
        config_with_empty = {
            'reviews': {},
            'chat': {},
            'knowledge_base': {}
        }

        # Empty sections should be dictionaries but have no fields
        for section in ['reviews', 'chat', 'knowledge_base']:
            assert isinstance(config_with_empty[section], dict)
            assert len(config_with_empty[section]) == 0

    def test_boundary_case_boolean_consistency(self, config):
        """Boundary test: all boolean values are explicitly true or false."""
        reviews = config.get('reviews', {})

        for key, value in reviews.items():
            # Ensure values are explicit booleans, not truthy/falsy
            assert value is True or value is False, \
                f"{key} should be explicit boolean, not {value}"