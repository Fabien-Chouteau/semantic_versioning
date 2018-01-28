with Ada.Strings.Maps;

package body Semantic_Versioning is

   -----------------
   -- New_Version --
   -----------------

   function New_Version (Description : Version_String) return Version is
      use Ada.Strings;
      use Ada.Strings.Fixed;
      use Ada.Strings.Maps;
      use Ustrings;

      First : Integer;
      Last  : Integer := Description'First - 1;

      type Seen_Parts is (None, Major, Minor, Patch);
      Seen : Seen_Parts := None;
   begin
      return V : Version do
         loop
            exit when Last = Description'Last;

            Find_Token (Description, (if Seen = Patch then To_Set ("+-")
                                                      else To_Set (".+-")),
                        Last + 1, Outside, First, Last);
            -- Whenever we move past the Patch number, there can be new dots in the
            -- Pre-release or build info

            exit when Last = 0;

            if First = Description'First then -- Major
               V.Major := Point'Value (Description (First .. Last));
               Seen    := Major;
            else
               if Seen = None then
                  raise Constraint_Error with "Major not found: " & Description;
               end if;

               case Description (First - 1) is
                  when '.' =>
                     if V.Pre_Release /= "" or else V.Build /= "" then
                        raise Constraint_Error with "Point after +-: " & Description;
                     end if;

                     if Seen = Major then
                        V.Minor := Point'Value (Description (First .. Last));
                        Seen    := Minor;
                     elsif Seen = Minor then
                        V.Patch := Point'Value (Description (First .. Last));
                        Seen    := Patch;
                     else
                        raise Constraint_Error with "Too many dots in version: " & Description;
                     end if;
                  when '-' =>
                     if V.Build /= "" then
                        raise Constraint_Error with "Build before Pre-Release: " & Description;
                     end if;
                     V.Pre_Release := To_Unbounded_String (Description (First .. Last));
                  when '+' =>
                     V.Build := To_Unbounded_String (Description (First .. Last));
                  when others =>
                     raise Constraint_Error with "Invalid separator: " & Description (First - 1);
               end case;
            end if;
         end loop;
      end return;
   end New_Version;

   ---------------------------
   -- Less_Than_Pre_Release --
   ---------------------------

   function Less_Than_Pre_Release (L, R : String) return Boolean is
      use Ada.Strings;
      use Ada.Strings.Fixed;
      use Ada.Strings.Maps;

      Dot : constant Character_Set := To_Set (".");
      L_First, L_Last : Natural := L'First - 1;
      R_First, R_Last : Natural := R'First - 1;
      L_Num, R_Num    : Integer;
   begin
      --  Special case if one of them is not really a pre-release:
      if L /= "" and then R = "" then
         return True;
      end if;

      loop
         if R_Last = R'Last then -- R depleted, at most L is depleted too
            return False;
         elsif L_Last = L'Last then -- L depleted, hence is <
            return True;
         else
            null; -- There are more tokens to compare
         end if;

         Find_Token (L, Dot, L_Last + 1, Outside, L_First, L_Last);
         Find_Token (R, Dot, R_Last + 1, Outside, R_First, R_Last);

         if R_Last = 0 then
            return False; -- L can't be less; at most equal (both empty)
         elsif L_Last = 0 then
            return True;  -- Since R is not exhausted but L is.
         else -- Field against field
              -- Compare field numerically, if possible:
            declare
               L_Str : String renames L (L_First .. L_Last);
               R_Str : String renames R (R_First .. R_Last);
            begin
               L_Num := Integer'Value (L_Str);
               R_Num := Integer'Value (R_str);

               if L_Num /= R_Num then
                  return L_Num < R_Num;
               else
                  null; -- Try next fields
               end if;
            exception
               when Constraint_Error => -- Can't convert, compare lexicographically
                  if L_Str /= R_Str then
                     return L_Str < R_Str;
                  else
                     null; -- Try next fields
                  end if;
            end;
         end if;
      end loop;
   end Less_Than_Pre_Release;

   ---------
   -- "<" --
   ---------

   function "<" (L, R : Version) return Boolean is
      use UStrings;
   begin
      if L.Major < R.Major then
         return True;
      elsif L.Major = R.Major then
         if L.Minor < R.Minor then
            return True;
         elsif L.Minor = R.Minor then
            if L.Patch < R.Patch then
               return True;
            elsif L.Patch = R.Patch then -- Pre-release versions are earlier than regular versions
               return Less_Than_Pre_Release (To_String (L.Pre_Release), To_String (R.Pre_Release));
            end if;
         end if;
      end if;

      return False; -- In all other cases
   end "<";

   -----------
   -- Is_In --
   -----------

   function Is_In (V : Version; VS : Version_Set) return Boolean is
   begin
      for R of VS loop
         if not Satisfies (V, R) then
            return False;
         end if;
      end loop;

      return True;
   end Is_In;

   ---------------
   -- Satisfies --
   ---------------

   function Satisfies (V : Version; R : Restriction) return Boolean is
   begin
      case R.Condition is
         when At_Least =>
            return V = R.On_Version or else R.On_Version < V;
         when At_Most =>
            return V < R.On_Version or else V = R.On_Version;
         when Exactly =>
            return V = R.On_Version;
         when Except =>
            return V /= R.On_Version;
      end case;
   end Satisfies;

end Semantic_Versioning;
