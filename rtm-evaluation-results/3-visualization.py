import os, sys
import numpy as np
from mayavi import mlab # mayavi package is required

mlab.options.offscreen = True

# Specify the file path
file_path = sys.argv[1] # original/reconstructed data
dim1 = int(sys.argv[2]) # 1008
dim2 = int(sys.argv[3]) # 1008
dim3 = int(sys.argv[4]) # 352

# Read the binary file into a NumPy array
data = np.fromfile(file_path, dtype=np.float32)
data = data.reshape((dim1, dim2, dim3))
print(data.max() - data.min())

# Set the color of the isosurface
color = (0.7, 0.7, 0.7)  # Grey color specified as RGB values

# Set the threshold value for the isosurface
# threshold = data.mean()  # Using the mean as a threshold for demonstration
threshold = 1

# Create the Mayavi figure and plot the isosurface
fig = mlab.figure(bgcolor=(1, 1, 1), size=(1024, 1024))
mlab.contour3d(data, contours=[threshold], color=color, opacity=0.5)

# Customize the plot appearance
# mlab.xlabel('X')
# mlab.ylabel('Y')
# mlab.zlabel('Z')
# mlab.title('3D Isosurface')

# Save the figure to a file
mlab.savefig(file_path + ".png")  # Specify the desired filename and path here

# Optionally, show the plot
# mlab.show()

# If you're running this script in a non-interactive environment (e.g., without a GUI),
# you might want to close the figure programmatically to free up system resources.
mlab.close(fig)