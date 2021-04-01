
/* Reflects declarations from the DWARF 3 to 5 specification, not the The D Language Foundation
 * dwarf implementation
 *
 * Source: $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dwarf2.d, backend/_dwarf2.d)
 */

module dmd.backend.dwarf2;

// Online documentation: https://dlang.org/phobos/dmd_backend_dwarf2.html

@safe:

enum
{
        DW_SECT_INFO                    = 1,
        DW_SECT_ABBREV                  = 3,
        DW_SECT_LINE                    = 4,
        DW_SECT_LOCLISTS                = 5,
        DW_SECT_STR_OFFSETS             = 6,
        DW_SECT_MACRO                   = 7,
        DW_SECT_RNGLISTS                = 8,
}

enum
{
        DW_UT_compile                   = 0x01,
        DW_UT_type                      = 0x02,
        DW_UT_partial                   = 0x03,
        DW_UT_skeleton                  = 0x04,
        DW_UT_split_compile             = 0x05,
        DW_UT_split_type                = 0x06,

        DW_UT_lo_user                   = 0x80,
        DW_UT_hi_user                   = 0xff,
}

enum
{
        DW_TAG_array_type               = 0x01,
        DW_TAG_class_type               = 0x02,
        DW_TAG_entry_point              = 0x03,
        DW_TAG_enumeration_type         = 0x04,
        DW_TAG_formal_parameter         = 0x05,
        DW_TAG_imported_declaration     = 0x08,
        DW_TAG_label                    = 0x0A,
        DW_TAG_lexical_block            = 0x0B,
        DW_TAG_member                   = 0x0D,
        DW_TAG_pointer_type             = 0x0F,
        DW_TAG_reference_type           = 0x10,
        DW_TAG_compile_unit             = 0x11,
        DW_TAG_string_type              = 0x12,
        DW_TAG_structure_type           = 0x13,
        DW_TAG_subroutine_type          = 0x15,
        DW_TAG_typedef                  = 0x16,
        DW_TAG_union_type               = 0x17,
        DW_TAG_unspecified_parameters   = 0x18,
        DW_TAG_variant                  = 0x19,
        DW_TAG_common_block             = 0x1A,
        DW_TAG_common_inclusion         = 0x1B,
        DW_TAG_inheritance              = 0x1C,
        DW_TAG_inlined_subroutine       = 0x1D,
        DW_TAG_module                   = 0x1E,
        DW_TAG_ptr_to_member_type       = 0x1F,
        DW_TAG_set_type                 = 0x20,
        DW_TAG_subrange_type            = 0x21,
        DW_TAG_with_stmt                = 0x22,
        DW_TAG_access_declaration       = 0x23,
        DW_TAG_base_type                = 0x24,
        DW_TAG_catch_block              = 0x25,
        DW_TAG_const_type               = 0x26,
        DW_TAG_constant                 = 0x27,
        DW_TAG_enumerator               = 0x28,
        DW_TAG_file_type                = 0x29,
        DW_TAG_friend                   = 0x2A,
        DW_TAG_namelist                 = 0x2B,
        DW_TAG_namelist_item            = 0x2C,
        DW_TAG_packed_type              = 0x2D,
        DW_TAG_subprogram               = 0x2E,
        DW_TAG_template_type_param      = 0x2F,
        DW_TAG_template_value_param     = 0x30,
        DW_TAG_thrown_type              = 0x31,
        DW_TAG_try_block                = 0x32,
        DW_TAG_variant_part             = 0x33,
        DW_TAG_variable                 = 0x34,
        DW_TAG_volatile_type            = 0x35,

        /* DWARF v3 */
        DW_TAG_dwarf_procedure          = 0x36,
        DW_TAG_restrict_type            = 0x37,
        DW_TAG_interface_type           = 0x38,
        DW_TAG_namespace                = 0x39,
        DW_TAG_imported_module          = 0x3A,
        DW_TAG_unspecified_type         = 0x3B,
        DW_TAG_partial_unit             = 0x3C,
        DW_TAG_imported_unit            = 0x3D,
        DW_TAG_condition                = 0x3F,
        DW_TAG_shared_type              = 0x40,

        /* DWARF v4 */
        DW_TAG_type_unit                = 0x41,
        DW_TAG_rvalue_reference_type    = 0x42,
        DW_TAG_template_alias           = 0x43,

        /* DWARF v5 */
        DW_TAG_coarray_type             = 0x44,
        DW_TAG_generic_subrange         = 0x45,
        DW_TAG_dynamic_type             = 0x46,
        DW_TAG_atomic_type              = 0x47,
        DW_TAG_call_site                = 0x48,
        DW_TAG_call_site_parameter      = 0x49,
        DW_TAG_skeleton_unit            = 0x4a,
        DW_TAG_immutable_type           = 0x4b,

        DW_TAG_lo_user                  = 0x4080,
        DW_TAG_hi_user                  = 0xFFFF,
}

enum
{
        DW_CHILDREN_no                  = 0x00,
        DW_CHILDREN_yes                 = 0x01,
}

enum
{
        DW_AT_sibling                   = 0x01,
        DW_AT_location                  = 0x02,
        DW_AT_name                      = 0x03,
        DW_AT_ordering                  = 0x09,
        DW_AT_byte_size                 = 0x0B,
        DW_AT_bit_offset                = 0x0C,
        DW_AT_bit_size                  = 0x0D,
        DW_AT_stmt_list                 = 0x10,
        DW_AT_low_pc                    = 0x11,
        DW_AT_high_pc                   = 0x12,
        DW_AT_language                  = 0x13,
        DW_AT_discr                     = 0x15,
        DW_AT_discr_value               = 0x16,
        DW_AT_visibility                = 0x17,
        DW_AT_import                    = 0x18,
        DW_AT_string_length             = 0x19,
        DW_AT_common_reference          = 0x1A,
        DW_AT_comp_dir                  = 0x1B,
        DW_AT_const_value               = 0x1C,
        DW_AT_containing_type           = 0x1D,
        DW_AT_default_value             = 0x1E,
        DW_AT_inline                    = 0x20,
        DW_AT_is_optional               = 0x21,
        DW_AT_lower_bound               = 0x22,
        DW_AT_producer                  = 0x25,
        DW_AT_prototyped                = 0x27,
        DW_AT_return_addr               = 0x2A,
        DW_AT_start_scope               = 0x2C,
        DW_AT_stride_size               = 0x2E,
        DW_AT_upper_bound               = 0x2F,
        DW_AT_abstract_origin           = 0x31,
        DW_AT_accessibility             = 0x32,
        DW_AT_address_class             = 0x33,
        DW_AT_artificial                = 0x34,
        DW_AT_base_types                = 0x35,
        DW_AT_calling_convention        = 0x36,
        DW_AT_count                     = 0x37,
        DW_AT_data_member_location      = 0x38,
        DW_AT_decl_column               = 0x39,
        DW_AT_decl_file                 = 0x3A,
        DW_AT_decl_line                 = 0x3B,
        DW_AT_declaration               = 0x3C,
        DW_AT_discr_list                = 0x3D,
        DW_AT_encoding                  = 0x3E,
        DW_AT_external                  = 0x3F,
        DW_AT_frame_base                = 0x40,
        DW_AT_friend                    = 0x41,
        DW_AT_identifier_case           = 0x42,
        DW_AT_macro_info                = 0x43,
        DW_AT_namelist_item             = 0x44,
        DW_AT_priority                  = 0x45,
        DW_AT_segment                   = 0x46,
        DW_AT_specification             = 0x47,
        DW_AT_static_link               = 0x48,
        DW_AT_type                      = 0x49,
        DW_AT_use_location              = 0x4A,
        DW_AT_variable_parameter        = 0x4B,
        DW_AT_virtuality                = 0x4C,
        DW_AT_vtable_elem_location      = 0x4D,

        /* DWARF v3 */
        DW_AT_allocated                 = 0x4E,
        DW_AT_associated                = 0x4F,
        DW_AT_data_location             = 0x50,
        DW_AT_byte_stride               = 0x51,
        DW_AT_entry_pc                  = 0x52,
        DW_AT_use_UTF8                  = 0x53,
        DW_AT_extension                 = 0x54,
        DW_AT_ranges                    = 0x55,
        DW_AT_trampoline                = 0x56,
        DW_AT_call_column               = 0x57,
        DW_AT_call_file                 = 0x58,
        DW_AT_call_line                 = 0x59,
        DW_AT_description               = 0x5A,
        DW_AT_binary_scale              = 0x5B,
        DW_AT_decimal_scale             = 0x5C,
        DW_AT_small                     = 0x5D,
        DW_AT_decimal_sign              = 0x5E,
        DW_AT_digit_count               = 0x5F,
        DW_AT_picture_string            = 0x60,
        DW_AT_mutable                   = 0x61,
        DW_AT_threads_scaled            = 0x62,
        DW_AT_explicit                  = 0x63,
        DW_AT_object_pointer            = 0x64,
        DW_AT_endianity                 = 0x65,
        DW_AT_elemental                 = 0x66,
        DW_AT_pure                      = 0x67,
        DW_AT_recursive                 = 0x68,

        /* DWARF v4 */
        DW_AT_signature                 = 0x69,
        DW_AT_main_subprogram           = 0x6a,
        DW_AT_data_bit_offset           = 0x6b,
        DW_AT_const_expr                = 0x6c,
        DW_AT_enum_class                = 0x6d,
        DW_AT_linkage_name              = 0x6e,

        /* DWARF v5 */
        DW_AT_string_length_bit_size    = 0x6f,
        DW_AT_string_length_byte_size   = 0x70,
        DW_AT_rank                      = 0x71,
        DW_AT_str_offsets_base          = 0x72,
        DW_AT_addr_base                 = 0x73,
        DW_AT_rnglists_base             = 0x74,
        DW_AT_dwo_name                  = 0x76,
        DW_AT_reference                 = 0x77,
        DW_AT_rvalue_reference          = 0x78,
        DW_AT_macros                    = 0x79,
        DW_AT_call_all_calls            = 0x7a,
        DW_AT_call_all_source_calls     = 0x7b,
        DW_AT_call_all_tail_calls       = 0x7c,
        DW_AT_call_return_pc            = 0x7d,
        DW_AT_call_value                = 0x7e,
        DW_AT_call_origin               = 0x7f,
        DW_AT_call_parameter            = 0x80,
        DW_AT_call_pc                   = 0x81,
        DW_AT_call_tail_call            = 0x82,
        DW_AT_call_target               = 0x83,
        DW_AT_call_target_clobbered     = 0x84,
        DW_AT_call_data_location        = 0x85,
        DW_AT_call_data_value           = 0x86,
        DW_AT_noreturn                  = 0x87,
        DW_AT_alignment                 = 0x88,
        DW_AT_export_symbols            = 0x89,
        DW_AT_deleted                   = 0x8a,
        DW_AT_defaulted                 = 0x8b,
        DW_AT_loclists_base             = 0x8c,

        DW_AT_lo_user                   = 0x2000,
        DW_AT_MIPS_linkage_name         = 0x2007,
        DW_AT_GNU_vector                = 0x2107,
        DW_AT_hi_user                   = 0x3FFF,
}

enum
{
        DW_FORM_addr                    = 0x01,
        DW_FORM_block2                  = 0x03,
        DW_FORM_block4                  = 0x04,
        DW_FORM_data2                   = 0x05,
        DW_FORM_data4                   = 0x06,
        DW_FORM_data8                   = 0x07,
        DW_FORM_string                  = 0x08,
        DW_FORM_block                   = 0x09,
        DW_FORM_block1                  = 0x0A,
        DW_FORM_data1                   = 0x0B,
        DW_FORM_flag                    = 0x0C,
        DW_FORM_sdata                   = 0x0D,
        DW_FORM_strp                    = 0x0E,
        DW_FORM_udata                   = 0x0F,
        DW_FORM_ref_addr                = 0x10,
        DW_FORM_ref1                    = 0x11,
        DW_FORM_ref2                    = 0x12,
        DW_FORM_ref4                    = 0x13,
        DW_FORM_ref8                    = 0x14,
        DW_FORM_ref_udata               = 0x15,
        DW_FORM_indirect                = 0x16,

        /* DWARF v4 */
        DW_FORM_sec_offset              = 0x17,
        DW_FORM_exprloc                 = 0x18,
        DW_FORM_flag_present            = 0x19,

        /* DWARF v5 */
        DW_FORM_strx                    = 0x1a,
        DW_FORM_addrx                   = 0x1b,
        DW_FORM_ref_sup4                = 0x1c,
        DW_FORM_strp_sup                = 0x1d,
        DW_FORM_data16                  = 0x1e,
        DW_FORM_line_strp               = 0x1f,

        /* DWARF v4 */
        DW_FORM_ref_sig8                = 0x20,

        /* DWARF v5 */
        DW_FORM_implicit_const          = 0x21,
        DW_FORM_loclistx                = 0x22,
        DW_FORM_rnglistx                = 0x23,
        DW_FORM_ref_sup8                = 0x24,
        DW_FORM_strx1                   = 0x25,
        DW_FORM_strx2                   = 0x26,
        DW_FORM_strx3                   = 0x27,
        DW_FORM_strx4                   = 0x28,
        DW_FORM_addrx1                  = 0x29,
        DW_FORM_addrx2                  = 0x2a,
        DW_FORM_addrx3                  = 0x2b,
        DW_FORM_addrx4                  = 0x2c,
}

enum
{
        DW_OP_addr                      = 0x03,
        DW_OP_deref                     = 0x06,
        DW_OP_const1u                   = 0x08,
        DW_OP_const1s                   = 0x09,
        DW_OP_const2u                   = 0x0a,
        DW_OP_const2s                   = 0x0b,
        DW_OP_const4u                   = 0x0c,
        DW_OP_const4s                   = 0x0d,
        DW_OP_const8u                   = 0x0e,
        DW_OP_const8s                   = 0x0f,
        DW_OP_constu                    = 0x10,
        DW_OP_consts                    = 0x11,
        DW_OP_dup                       = 0x12,
        DW_OP_drop                      = 0x13,
        DW_OP_over                      = 0x14,
        DW_OP_pick                      = 0x15,
        DW_OP_swap                      = 0x16,
        DW_OP_rot                       = 0x17,
        DW_OP_xderef                    = 0x18,
        DW_OP_abs                       = 0x19,
        DW_OP_and                       = 0x1a,
        DW_OP_div                       = 0x1b,
        DW_OP_minus                     = 0x1c,
        DW_OP_mod                       = 0x1d,
        DW_OP_mul                       = 0x1e,
        DW_OP_neg                       = 0x1f,
        DW_OP_not                       = 0x20,
        DW_OP_or                        = 0x21,
        DW_OP_plus                      = 0x22,
        DW_OP_plus_uconst               = 0x23,
        DW_OP_shl                       = 0x24,
        DW_OP_shr                       = 0x25,
        DW_OP_shra                      = 0x26,
        DW_OP_xor                       = 0x27,
        DW_OP_skip                      = 0x2f,
        DW_OP_bra                       = 0x28,
        DW_OP_eq                        = 0x29,
        DW_OP_ge                        = 0x2a,
        DW_OP_gt                        = 0x2b,
        DW_OP_le                        = 0x2c,
        DW_OP_lt                        = 0x2d,
        DW_OP_ne                        = 0x2e,
        DW_OP_lit0                      = 0x30,
        DW_OP_lit1                      = 0x31,
        // ...
        DW_OP_lit31                     = 0x4f,
        DW_OP_reg0                      = 0x50,
        DW_OP_reg1                      = 0x51,
        // ...
        DW_OP_reg31                     = 0x6f,
        DW_OP_breg0                     = 0x70,
        DW_OP_breg1                     = 0x71,
        // ...
        DW_OP_breg31                    = 0x8f,
        DW_OP_regx                      = 0x90,
        DW_OP_fbreg                     = 0x91,
        DW_OP_bregx                     = 0x92,
        DW_OP_piece                     = 0x93,
        DW_OP_deref_size                = 0x94,
        DW_OP_xderef_size               = 0x95,
        DW_OP_nop                       = 0x96,

        /* DWARF v3 */
        DW_OP_push_object_address       = 0x97,
        DW_OP_call2                     = 0x98,
        DW_OP_call4                     = 0x99,
        DW_OP_call_ref                  = 0x9a,
        DW_OP_form_tls_address          = 0x9b,
        DW_OP_call_frame_cfa            = 0x9c,
        DW_OP_bit_piece                 = 0x9d,

        /* DWARF v4 */
        DW_OP_implicit_value            = 0x9e,
        DW_OP_stack_value               = 0x9f,

        /* DWARF v5 */
        DW_OP_implicit_pointer          = 0xa0,
        DW_OP_addrx                     = 0xa1,
        DW_OP_constx                    = 0xa2,
        DW_OP_entry_value               = 0xa3,
        DW_OP_const_type                = 0xa4,
        DW_OP_regval_type               = 0xa5,
        DW_OP_deref_type                = 0xa6,
        DW_OP_xderef_type               = 0xa7,
        DW_OP_convert                   = 0xa8,
        DW_OP_reinterpret               = 0xa9,

        /* GNU extensions. */
        DW_OP_GNU_push_tls_address      = 0xe0,

        DW_OP_lo_user                   = 0xe0,
        DW_OP_hi_user                   = 0xff,
}

enum
{
        DW_ATE_address                  = 0x01,
        DW_ATE_boolean                  = 0x02,
        DW_ATE_complex_float            = 0x03,
        DW_ATE_float                    = 0x04,
        DW_ATE_signed                   = 0x05,
        DW_ATE_signed_char              = 0x06,
        DW_ATE_unsigned                 = 0x07,
        DW_ATE_unsigned_char            = 0x08,

        /* DWARF v3 */
        DW_ATE_imaginary_float          = 0x09,
        DW_ATE_packed_decimal           = 0x0a,
        DW_ATE_numeric_string           = 0x0b,
        DW_ATE_edited                   = 0x0c,
        DW_ATE_signed_fixed             = 0x0d,
        DW_ATE_unsigned_fixed           = 0x0e,
        DW_ATE_decimal_float            = 0x0f,

        /* DWARF v4 */
        DW_ATE_UTF                      = 0x10,

        /* DWARF v5 */
        DW_ATE_UCS                      = 0x11,
        DW_ATE_ASCII                    = 0x12,

        DW_ATE_lo_user                  = 0x80,
        DW_ATE_hi_user                  = 0xff,
}

enum
{
        /* DWARF v5 */
        DW_LLE_end_of_list              = 0x00,
        DW_LLE_base_addressx            = 0x01,
        DW_LLE_startx_endx              = 0x02,
        DW_LLE_startx_length            = 0x03,
        DW_LLE_offset_pair              = 0x04,
        DW_LLE_default_location         = 0x05,
        DW_LLE_base_address             = 0x06,
        DW_LLE_start_end                = 0x07,
        DW_LLE_start_length             = 0x08,
}

enum
{
        DW_DS_unsigned                  = 0x01,
        DW_DS_leading_overpunch         = 0x02,
        DW_DS_trailing_overpunch        = 0x03,
        DW_DS_leading_separate          = 0x04,
        DW_DS_trailing_separate         = 0x05,
}

enum
{
        DW_END_default                  = 0x00,
        DW_END_big                      = 0x01,
        DW_END_little                   = 0x02,
        DW_END_lo_user                  = 0x40,
        DW_END_hi_user                  = 0xff,
}

enum
{
        DW_ACCESS_public                = 0x01,
        DW_ACCESS_protected             = 0x02,
        DW_ACCESS_private               = 0x03,
}

enum
{
        DW_VIS_local                    = 0x01,
        DW_VIS_exported                 = 0x02,
        DW_VIS_qualified                = 0x03,
}

enum
{
        DW_VIRTUALITY_none              = 0x00,
        DW_VIRTUALITY_virtual           = 0x01,
        DW_VIRTUALITY_pure_virtual      = 0x02,
}

enum
{
        DW_LANG_C89                     = 0x0001,
        DW_LANG_C                       = 0x0002,
        DW_LANG_Ada83                   = 0x0003,
        DW_LANG_C_plus_plus             = 0x0004,
        DW_LANG_Cobol74                 = 0x0005,
        DW_LANG_Cobol85                 = 0x0006,
        DW_LANG_Fortran77               = 0x0007,
        DW_LANG_Fortran90               = 0x0008,
        DW_LANG_Pascal83                = 0x0009,
        DW_LANG_Modula2                 = 0x000a,
        DW_LANG_Java                    = 0x000b,
        DW_LANG_C99                     = 0x000c,
        DW_LANG_Ada95                   = 0x000d,
        DW_LANG_Fortran95               = 0x000e,
        DW_LANG_PLI                     = 0x000f,
        DW_LANG_ObjC                    = 0x0010,
        DW_LANG_ObjC_plus_plus          = 0x0011,
        DW_LANG_UPC                     = 0x0012,
        DW_LANG_D                       = 0x0013,
        DW_LANG_Python                  = 0x0014,

        /* DWARF v5 */
        DW_LANG_OpenCL                  = 0x0015,
        DW_LANG_Go                      = 0x0016,
        DW_LANG_Modula3                 = 0x0017,
        DW_LANG_Haskell                 = 0x0018,
        DW_LANG_C_plus_plus_03          = 0x0019,
        DW_LANG_C_plus_plus_11          = 0x001a,
        DW_LANG_OCaml                   = 0x001b,
        DW_LANG_Rust                    = 0x001c,
        DW_LANG_C11                     = 0x001d,
        DW_LANG_Swift                   = 0x001e,
        DW_LANG_Julia                   = 0x001f,
        DW_LANG_Dylan                   = 0x0020,
        DW_LANG_C_plus_plus_14          = 0x0021,
        DW_LANG_Fortran03               = 0x0022,
        DW_LANG_Fortran08               = 0x0023,
        DW_LANG_RenderScript            = 0x0024,
        DW_LANG_BLISS                   = 0x0025,

        DW_LANG_lo_user                 = 0x8000,
        DW_LANG_hi_user                 = 0xffff,
}

enum
{
        DW_ID_case_sensitive            = 0x00,
        DW_ID_up_case                   = 0x01,
        DW_ID_down_case                 = 0x02,
        DW_ID_case_insensitive          = 0x03,
}

enum
{
        DW_CC_normal                    = 0x01,
        DW_CC_program                   = 0x02,
        DW_CC_nocall                    = 0x03,

        /* DWARF v5 */
        DW_CC_pass_by_reference         = 0x04,
        DW_CC_pass_by_value             = 0x05,

        DW_CC_lo_user                   = 0x40,
        DW_CC_hi_user                   = 0xff,
}

enum
{
        DW_INL_not_inlined              = 0x00,
        DW_INL_inlined                  = 0x01,
        DW_INL_declared_not_inlined     = 0x02,
        DW_INL_declared_inlined         = 0x03,
}

enum
{
        DW_ORD_row_major                = 0x00,
        DW_ORD_col_major                = 0x01,
}

enum
{
        /* DWARF v5 */
        DW_IDX_compile_unit             = 1,
        DW_IDX_type_unit                = 2,
        DW_IDX_die_offset               = 3,
        DW_IDX_parent                   = 4,
        DW_IDX_type_hash                = 5,

        DW_IDX_lo_user                  = 0x2000,
        DW_IDX_hi_user                  = 0x3fff,
}

enum
{
        /* DWARF v5 */
        DW_DEFAULTED_no                 = 0x00,
        DW_DEFAULTED_in_class           = 0x01,
        DW_DEFAULTED_out_of_class       = 0x02,
}

enum
{
        DW_DSC_label                    = 0x00,
        DW_DSC_range                    = 0x01,
}

enum
{
        DW_LNS_copy                     = 0x01,
        DW_LNS_advance_pc               = 0x02,
        DW_LNS_advance_line             = 0x03,
        DW_LNS_set_file                 = 0x04,
        DW_LNS_set_column               = 0x05,
        DW_LNS_negate_stmt              = 0x06,
        DW_LNS_set_basic_block          = 0x07,
        DW_LNS_const_add_pc             = 0x08,
        DW_LNS_fixed_advance_pc         = 0x09,
        DW_LNS_set_prologue_end         = 0x0a,
        DW_LNS_set_epilogue_begin       = 0x0b,
        DW_LNS_set_isa                  = 0x0c,
}

enum
{
        DW_LNE_end_sequence             = 0x01,
        DW_LNE_set_address              = 0x02,
        DW_LNE_define_file              = 0x03, // DWARF v4 and earlier only
        DW_LNE_lo_user                  = 0x80,
        DW_LNE_hi_user                  = 0xff,
}

enum
{
        /* DWARF v5 */
        DW_LNCT_path                    = 0x1,
        DW_LNCT_directory_index         = 0x2,
        DW_LNCT_timestamp               = 0x3,
        DW_LNCT_size                    = 0x4,
        DW_LNCT_MD5                     = 0x5,

        DW_LNCT_lo_user                 = 0x2000,
        DW_LNCT_hi_user                 = 0x3fff,
}

enum
{
        DW_MACINFO_define       = 0x01,
        DW_MACINFO_undef        = 0x02,
        DW_MACINFO_start_file   = 0x03,
        DW_MACINFO_end_file     = 0x04,
        DW_MACINFO_vendor_ext   = 0xff,
}

enum
{
        /* DWARF v5 */
        DW_MACRO_define                 = 0x01,
        DW_MACRO_undef                  = 0x02,
        DW_MACRO_start_file             = 0x03,
        DW_MACRO_end_file               = 0x04,
        DW_MACRO_define_strp            = 0x05,
        DW_MACRO_undef_strp             = 0x06,
        DW_MACRO_import                 = 0x07,
        DW_MACRO_define_sup             = 0x08,
        DW_MACRO_undef_sup              = 0x09,
        DW_MACRO_import_sup             = 0x0a,
        DW_MACRO_define_strx            = 0x0b,
        DW_MACRO_undef_strx             = 0x0c,

        DW_MACRO_lo_user                = 0xe0,
        DW_MACRO_hi_user                = 0xff,
}

enum
{
        DW_CFA_advance_loc              = 0x40,
        DW_CFA_offset                   = 0x80,
        DW_CFA_restore                  = 0xc0,
        DW_CFA_nop                      = 0x00,
        DW_CFA_set_loc                  = 0x01,
        DW_CFA_advance_loc1             = 0x02,
        DW_CFA_advance_loc2             = 0x03,
        DW_CFA_advance_loc4             = 0x04,
        DW_CFA_offset_extended          = 0x05,
        DW_CFA_restore_extended         = 0x06,
        DW_CFA_undefined                = 0x07,
        DW_CFA_same_value               = 0x08,
        DW_CFA_register                 = 0x09,
        DW_CFA_remember_state           = 0x0a,
        DW_CFA_restore_state            = 0x0b,
        DW_CFA_def_cfa                  = 0x0c,
        DW_CFA_def_cfa_register         = 0x0d,
        DW_CFA_def_cfa_offset           = 0x0e,

        /* DWARF v3 */
        DW_CFA_def_cfa_expression       = 0x0f,
        DW_CFA_expression               = 0x10,
        DW_CFA_offset_extended_sf       = 0x11,
        DW_CFA_def_cfa_sf               = 0x12,
        DW_CFA_def_cfa_offset_sf        = 0x13,
        DW_CFA_val_offset               = 0x14,
        DW_CFA_val_offset_sf            = 0x15,
        DW_CFA_val_expression           = 0x16,

        /* GNU extensions. */
        DW_CFA_GNU_window_save          = 0x2d,
        DW_CFA_GNU_args_size            = 0x2e,
        DW_CFA_GNU_negative_offset_extended = 0x2f,

        DW_CFA_lo_user                  = 0x1c,
        DW_CFA_hi_user                  = 0x3f,
}

enum
{
        DW_EH_PE_FORMAT_MASK            = 0x0F,
        DW_EH_PE_APPL_MASK              = 0x70,
        DW_EH_PE_indirect               = 0x80,

        DW_EH_PE_omit                   = 0xFF,
        DW_EH_PE_ptr                    = 0x00,
        DW_EH_PE_uleb128                = 0x01,
        DW_EH_PE_udata2                 = 0x02,
        DW_EH_PE_udata4                 = 0x03,
        DW_EH_PE_udata8                 = 0x04,
        DW_EH_PE_sleb128                = 0x09,
        DW_EH_PE_sdata2                 = 0x0A,
        DW_EH_PE_sdata4                 = 0x0B,
        DW_EH_PE_sdata8                 = 0x0C,

        DW_EH_PE_absptr                 = 0x00,
        DW_EH_PE_pcrel                  = 0x10,
        DW_EH_PE_textrel                = 0x20,
        DW_EH_PE_datarel                = 0x30,
        DW_EH_PE_funcrel                = 0x40,
        DW_EH_PE_aligned                = 0x50,
}

enum
{
        /* DWARF v5 */
        DW_RLE_end_of_list              = 0x00,
        DW_RLE_base_addressx            = 0x01,
        DW_RLE_startx_endx              = 0x02,
        DW_RLE_startx_length            = 0x03,
        DW_RLE_offset_pair              = 0x04,
        DW_RLE_base_address             = 0x05,
        DW_RLE_start_end                = 0x06,
        DW_RLE_start_length             = 0x07,
}

