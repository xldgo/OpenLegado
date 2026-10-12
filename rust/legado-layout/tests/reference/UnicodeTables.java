// 从对照运行时的 Character 分类生成表，避免 Rust 与 Java Unicode 版本漂移。
import java.nio.file.*;
import java.util.function.IntPredicate;

class UnicodeTables {
    static String ranges(String name, IntPredicate predicate) {
        var out = new StringBuilder("pub const " + name + ": &[(u32,u32)] = &[\n");
        int start = -1;
        for (int cp = 0; cp <= 0x110000; cp++) {
            boolean matches = cp < 0x110000 && predicate.test(cp);
            if (matches && start < 0) start = cp;
            if (!matches && start >= 0) {
                out.append(String.format("(0x%x,0x%x),\n", start, cp - 1));
                start = -1;
            }
        }
        return out.append("];\n").toString();
    }
    public static void main(String[] args) throws Exception {
        var out = "// 由 tests/reference/UnicodeTables.java 生成；对照 JDK " + System.getProperty("java.version") + "。\n";
        out += ranges("LETTERS", Character::isLetter);
        out += ranges("LATIN", cp -> Character.isLetter(cp) && Character.UnicodeScript.of(cp) == Character.UnicodeScript.LATIN);
        out += ranges("DIGITS", Character::isDigit);
        out += ranges("MARKS", cp -> Character.getType(cp) == Character.NON_SPACING_MARK || Character.getType(cp) == Character.COMBINING_SPACING_MARK);
        Files.writeString(Path.of(args[0]), out);
    }
}
