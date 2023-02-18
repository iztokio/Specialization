Console.Write("Enter the number of strings: ");
int n = int.Parse(Console.ReadLine() ?? "0");
string[] strings = new string[n];
Console.WriteLine("Enter the strings: ");
for (int i = 0; i < n; i++)
{
    strings[i] = Console.ReadLine();
}
int count = 0;
for (int i = 0; i < n; i++)
{
    if (strings[i].Length <= 3)
    {
        count++;
    }
}
string[] newStrings = new string[count];
int index = 0;
for (int i = 0; i < n; i++)
{
    if (strings[i].Length <= 3)
    {
        newStrings[index] = strings[i];
        index++;
    }
}
Console.WriteLine("Strings with length less than or equal to 3 characters: ");
for (int i = 0; i < count; i++)
{
    Console.WriteLine(newStrings[i]);
}